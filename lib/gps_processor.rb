module GpsProcessor

  def self.process_result(entry)
    entry.reset_result!

    #for each leg
    leg_no=1
    nongauntlet_dist_sum=0
    gauntlet_dist_sum=0
    check_from=nil

    entry.checkins.order(:checkin_number).each do |check_to|
      unless check_from.nil?

        low_guard=[check_from.guard_id, check_to.guard_id].min
        high_guard=[check_from.guard_id, check_to.guard_id].max

        #get or create leg
        leg=Leg.where(guard1_id: low_guard, guard2_id: high_guard).first
        if leg.nil?
          dist=ActiveRecord::Base.connection.exec_query("SELECT ec_guardsdistance(#{low_guard},#{high_guard})").rows[0][0]
          leg=entry.charge.legs.new(guard1_id: low_guard, guard2_id: high_guard, distance_m: dist)
          if check_from.guard.is_gauntlet and check_to.guard.is_gauntlet
            leg.is_gauntlet=true
          else
            leg.is_gauntlet=false
          end
          leg.save!
        end

        #create the entry_leg
        elapsed=check_to.checkin_timestamp-check_from.checkin_timestamp
        entry_leg=entry.entry_legs.new(leg_id: leg.id, checkin1_id: check_from.id, checkin2_id: check_to.id, leg_number: leg_no, elapsed_s: elapsed)
        entry_leg.save!
        ActiveRecord::Base.connection.exec_query("SELECT ec_entrylegcreateline (#{entry_leg.id})")
        entry_leg.reload

        if check_from.guard.id==low_guard
          entry_leg.direction_forward=true
        else
          entry_leg.direction_forward=false
        end
        if leg.is_gauntlet
          gauntlet_dist_sum+=entry_leg.distance_m
        else
          nongauntlet_dist_sum+=entry_leg.distance_m
        end
        entry_leg.save!
        leg_no+=1
      end
      check_from=check_to
    end

    entry.result_guards=leg_no

    #dist_nongauntlet;
    entry.dist_nongauntlet=nongauntlet_dist_sum;

    #dist_gauntlet;
    entry.dist_gauntlet=gauntlet_dist_sum;

    #dist_withpentalty_nongauntlet;
    entry.dist_withpentalty_nongauntlet=nongauntlet_dist_sum + entry.dist_penalty_nongauntlet

    #dist_withpentalty_gauntlet;
    entry.dist_withpentalty_gauntlet=gauntlet_dist_sum + entry.dist_penalty_gauntlet

    #dist_multiplied_gauntlet;
    entry.dist_multiplied_gauntlet=entry.dist_withpentalty_gauntlet*entry.charge.gauntlet_multiplier

    #dist_real;
    entry.dist_real=nongauntlet_dist_sum+gauntlet_dist_sum;

    #dist_competition;
    entry.dist_competition=entry.dist_withpentalty_nongauntlet+entry.dist_multiplied_gauntlet

    entry.save!
  end

  def self.guess_checkins(entry)

    entry.reset_checkins!

    pnts=ActiveRecord::Base.connection.exec_query("SELECT * FROM ec_pointswithinguardforentry(#{entry.id})").rows
    #guard_id , gps_clean_id , gps_timestamp , dist_m

    #split by guard 'hits'
    hits=[]
    cur_hit={guard_id: pnts[0][0], gps_clean_id: pnts[0][1], points: []}
    hits<<cur_hit
    previous_guards={}
    prev_clean_id=-1

    pnts.each_with_index do |pnt, i|
      if ActiveSupport::TimeZone['UTC'].parse(pnt[2])>entry.charge.start_datetime
        if pnt[0]!=cur_hit[:guard_id] or ((pnt[1]-prev_clean_id)>30 and prev_clean_id!=-1) #new guard hit
          cur_hit=Hash.new()
          cur_hit={guard_id: pnt[0], gps_clean_id: pnt[1], points: []}
          hits<<cur_hit

          unless previous_guards[pnt[0]].nil?
            cur_hit[:duplicate]=true
            previous_guards[pnt[0]][:duplicate]=true
          end
          previous_guards[pnt[0]]=cur_hit
        end
        prev_clean_id=pnt[1]
        cur_hit[:points]<<pnt


      end
    end

    #for each hit find the point closest to the guard
    hits.each_with_index do |hit, i|
      closest=hit[:points].min { |a, b| a[3]<=> b[3] }
      check=entry.checkins.new(
          checkin_timestamp: ActiveSupport::TimeZone['UTC'].parse(closest[2]),
          checkin_number: i+1,
          guard_id: hit[:guard_id],
          gps_clean_id: closest[1],
          is_duplicate: hit[:duplicate].nil? ? false : true
      )
      check.save!
    end
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
    peek_offset=0; sum_x=0; sum_y=0;
    stops=[]
    raws.each_with_index do |raw, i|
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
          peek_offset=0; sum_x=0; sum_y=0;
        end
      else
        peek_offset-=1
        sum_x=0; sum_y=0;
      end
    end

    #amalgamte consecutive stops
    peek_offset=0
    stops_combined=[]
    stops.each_with_index do |stop, i|
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
          peek_offset=0; sum_x=0; sum_y=0
          stops_combined<<stop
        end
      else
        peek_offset-=1
        sum_x=0; sum_y=0
      end
    end

    #output clean points and stops
    #enumerate clean points and hold a pointer against stops
    stop_i=0
    raws.each_with_index do |raw, raw_i|
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

  def self.output_clean(entry_id, gps_timestamp, location_prj_x, location_prj_y, stop_id=nil)
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

  def self.output_stop(entry_id, start_timestamp, end_timestamp, location_prj_x, location_prj_y)
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
