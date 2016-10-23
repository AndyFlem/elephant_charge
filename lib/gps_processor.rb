module GpsProcessor

  def self.process_result(entry)

    entry.entry_legs.destroy_all

    from_time=entry.charge.start_datetime
    to_time=from_time+2.hours

    previous_checkin=nil
    missing_leg=false

    entry.checkins.order(:checkin_timestamp).each_with_index do |checkin,i|
      qry="SELECT * FROM ec_guardcheckinforentry(#{entry.id},#{checkin.guard.id},'#{from_time.utc}','#{to_time.utc}')"
      puts qry
      pnt=ActiveRecord::Base.connection.exec_query(qry).rows[0]
      unless pnt.nil?
        clean=GpsClean.find(pnt[1])
        checkin.gps_clean=clean
        checkin.checkin_timestamp=clean.gps_timestamp
        checkin.processed=true
        checkin.save!

        #create the entry_leg (and leg if needed)
        unless previous_checkin.nil?
          low_guard=[checkin.guard_id,previous_checkin.guard_id].min
          high_guard=[checkin.guard_id,previous_checkin.guard_id].max

          #get or create leg
          leg=Leg.where(guard1_id: low_guard,guard2_id: high_guard).first
          if leg.nil?
            dist=ActiveRecord::Base.connection.exec_query("SELECT ec_guardsdistance(#{low_guard},#{high_guard})").rows[0][0]
            leg=Leg.new(guard1_id: low_guard,guard2_id: high_guard,distance_m: dist)
            leg.save!
          end

          #create the entry_leg
          entry_leg=entry.entry_legs.new(leg_id: leg.id, checkin1_id:previous_checkin.id, checkin2_id: checkin.id)
          entry_leg.save!
          ActiveRecord::Base.connection.exec_query("SELECT ec_entrylegcreateline (#{entry_leg.id})")
        end

        previous_checkin=checkin
        from_time=checkin.checkin_timestamp
      else
        checkin.gps_clean=nil
        checkin.checkin_timestamp=nil
        checkin.processed=false
        checkin.save!
        previous_checkin=nil
        missing_leg=true;
        raise "Ouch"
      end
      to_time=entry.charge.end_datetime
    end

  end

  def self.guess_checkins(entry)

    entry.entry_legs.destroy_all

    entry.checkins.destroy_all

    pnts=ActiveRecord::Base.connection.exec_query("SELECT * FROM ec_pointswithinguardforentry(#{entry.id})").rows
    #guard_id , gps_clean_id , gps_timestamp , dist_m

    cur_guard=-1
    checkin_number=1
    pnts.each_with_index do |pnt,i|
      if pnt[0]!=cur_guard
        check=entry.checkins.new(checkin_timestamp: ActiveSupport::TimeZone['UTC'].parse(pnt[2]), checkin_number: checkin_number, guard_id: pnt[0])
        check.save
        checkin_number+=1
        cur_guard=pnt[0]
      end
    end
    entry.result_messages=[]
    if checkin_number<12
      entry.result_messages<<"Incomplete checkpoint record (#{(checkin_number-1).to_s} of 11)"
    end
    if entry.checkins.first.guard.id!=entry.start_guard.id
      entry.result_messages<<"Unexpected starting checkpoint. #{entry.checkins.first.guard.name} instead of #{entry.start_guard.name} "
    end

    entry.save!

  end

  def self.process_raw(entry)


    ActiveRecord::Base.connection.exec_query("SELECT ec_gpsrawsupdatecalcs(#{entry.id})")
    ActiveRecord::Base.connection.exec_query("SELECT ec_gpsrawscreateline(#{entry.id})")
    entry.state_ref="RAW"
    entry.entry_geom.reload
    if entry.entry_geom.raws_from>entry.charge.start_datetime
      if entry.state_messages.nil?
        entry.state_messages=["Raw track missing start."]
      else
        entry.state_messages<<"Raw track missing start."
      end

    end
    if entry.entry_geom.raws_to<entry.charge.end_datetime
      if entry.state_messages.nil?
        entry.state_messages=["Raw track missing end."]
      else
        entry.state_messages<<"Raw track missing end."
      end
    end
    entry.save!

  end

  def self.process_clean(entry)
    entry.reset_clean!

    #find gaps

    #remove spikes

    #===============
    #find stops
    #===============
    stop_radius=10 #meters
    min_stop_points=6

    #iterate points for stop candidates
    raws=entry.gps_raws.order(:gps_timestamp)
    raws_count=raws.count
    peek_offset=0;sum_x=0;sum_y=0;
    stops=[]
    raws.each_with_index do |raw,i|
      if peek_offset==0 #skip already processed

        #peek forward until point is greater than stop radius
        #if we need to peek more than min_stop_points then its a stop
        #collapse onto av pos
        while i+peek_offset+1<raws_count and raw.location_prj.distance(raws[i+peek_offset+1].location_prj)<stop_radius
          sum_x+=raws[i+peek_offset].location_prj.x
          sum_y+=raws[i+peek_offset].location_prj.y
          peek_offset+=1
        end

        if peek_offset>min_stop_points
          #stop found
          stops<<{
              from_index: i, to_index: i+peek_offset,
              location_prj_x: sum_x/peek_offset, location_prj_y: sum_y/peek_offset
          }
        else
          #no stop
          peek_offset=0; sum_x=0;sum_y=0;
        end
      else
        peek_offset-=1
        sum_x=0;sum_y=0;
      end
    end

    #amalgamte consecutive stops
    peek_offset=0
    stops_combined=[]
    stops.each_with_index do |stop,i|
      if peek_offset==0 #skip already processed

        #peek forward while stops consecutive
        while i+peek_offset+1<stops.count and stops[i+peek_offset][:to_index]==stops[i+peek_offset+1][:from_index]-1
          sum_x+=stops[i+peek_offset][:location_prj_x]
          sum_y+=stops[i+peek_offset][:location_prj_y]
          peek_offset+=1
        end

        if peek_offset>0
          #amalgamate
          stops_combined<<{
              from_index: stop[:from_index], to_index: stops[i+peek_offset][:to_index],
              location_prj_x: sum_x/peek_offset, location_prj_y: sum_y/peek_offset,
          }
        else
          #emit
          peek_offset=0; sum_x=0;sum_y=0
          stops_combined<<stop
        end
      else
        peek_offset-=1
        sum_x=0;sum_y=0
      end
    end

    #output clean points and stops
    #enumerate clean points and hold a pointer against stops
    stop_i=0
    raws.each_with_index do |raw,raw_i|
      if stop_i<stops_combined.count and
          raw_i >= stops_combined[stop_i][:from_index] and
          raw_i <= stops_combined[stop_i][:to_index]

        #in a stop
        if raw_i==stops_combined[stop_i][:to_index]
          stop_id=output_stop(
              entry.id,
              raws[stops_combined[stop_i][:from_index]].gps_timestamp,
              raws[raw_i].gps_timestamp,
              stops_combined[stop_i][:location_prj_x],
              stops_combined[stop_i][:location_prj_y])

          output_clean(
              entry.id,
              raws[stops_combined[stop_i][:from_index]].gps_timestamp,
              stops_combined[stop_i][:location_prj_x],
              stops_combined[stop_i][:location_prj_y],
              stop_id)

          output_clean(
              entry.id, raw.gps_timestamp,
              stops_combined[stop_i][:location_prj_x],
              stops_combined[stop_i][:location_prj_y])
          stop_i+=1
        end
      else
        #no stop
        output_clean entry.id, raw.gps_timestamp, raw.location_prj.x, raw.location_prj.y
      end
    end

    #output clean
    ActiveRecord::Base.connection.exec_query("SELECT ec_gpscleansupdatecalcs(#{entry.id})")
    ActiveRecord::Base.connection.exec_query("SELECT ec_gpscleanscreateline(#{entry.id})")
    entry.state_ref="CLEAN"
    entry.save!
  end

  def self.output_clean(entry_id,gps_timestamp,location_prj_x,location_prj_y,stop_id=nil)
    query = <<-SQL
            INSERT INTO gps_cleans (entry_id,gps_timestamp,location_prj,location,stop_id) VALUES (
              #{entry_id},
              '#{gps_timestamp.utc}',
              ST_GeomFromText('POINT (#{location_prj_x} #{location_prj_y})',3857),
              ST_Transform(ST_GeomFromText('POINT (#{location_prj_x} #{location_prj_y})',3857),4326),
              #{stop_id.nil? ? 'null' : stop_id}
          );
    SQL
    ActiveRecord::Base.connection.exec_query(query)
  end

  def self.output_stop(entry_id,start_timestamp,end_timestamp,location_prj_x,location_prj_y)
    query = <<-SQL
            INSERT INTO gps_stops (entry_id,start_timestamp,end_timestamp,location_prj,location) VALUES (
              #{entry_id},
              '#{start_timestamp.utc}',
              '#{end_timestamp.utc}',
              ST_GeomFromText('POINT (#{location_prj_x} #{location_prj_y})',3857),
              ST_Transform(ST_GeomFromText('POINT (#{location_prj_x} #{location_prj_y})',3857),4326)
          ) RETURNING id;
    SQL
    res=ActiveRecord::Base.connection.exec_query(query)
    res.rows[0][0]
  end
end
