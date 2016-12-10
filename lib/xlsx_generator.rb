require 'axlsx'

module XlsxGenerator


  def self.charge_xl(charge)
    h=Helpers.new

    p = Axlsx::Package.new
    wb = p.workbook


      wb.styles do |s|
        title_cell = s.add_style :b=>true,:bg_color => "FFFFFF", :fg_color => "df5409", :sz => 14, :alignment => { :horizontal=> :left }
        sub_title_cell = s.add_style :b=>true,:bg_color => "FFFFFF", :fg_color => "000000", :sz => 12, :alignment => { :horizontal=> :left }
        head_cell = s.add_style :border => { :style => :thin, :color => "00" },:bg_color => "eeeeee", :fg_color => "000000", :sz => 11, :alignment => { :horizontal=> :left }
        high_cell = s.add_style  :border => { :style => :thin, :color => "00" },:b=>true,:bg_color => "FFFFFF", :fg_color => "000000", :sz => 9, :alignment => { :horizontal=> :left }

        main_cell = s.add_style  :border => { :style => :thin, :color => "00" },:bg_color => "FFFFFF", :fg_color => "000000", :sz => 9, :alignment => { :horizontal=> :left }
        main_wrap = s.add_style({:border => { :style => :thin, :color => "00" },:bg_color => "FFFFFF", :fg_color => "000000", :sz => 9, :alignment => {:horizontal => :left, :vertical => :top, :wrap_text => true}}  )
        high_wrap = s.add_style  :border => { :style => :thin, :color => "00" },:b=>true,:bg_color => "FFFFFF", :fg_color => "000000", :sz => 9, :alignment => { :horizontal=> :left, :vertical => :top }

        wb.add_worksheet(:name => "Charge") do |sheet|
          sheet.add_row [charge.long_name],:style => title_cell
          sheet.add_row ["Summary"],:style => sub_title_cell
          sheet.add_row

          sheet.add_row [
                            "Date",charge.charge_date.strftime("%a %d %b %Y"),
                            "",
                            "Bike Teams",charge.entries.where(is_bikes: true).count
                        ],:style=>[head_cell,high_cell,nil,head_cell,high_cell]

          sheet.add_row [
                            "Teams",charge.entries.count,
                            "",
                            "Ladies Teams",charge.entries.where(is_ladies: true).count
                        ],:style=>[head_cell,high_cell,nil,head_cell,high_cell]


          sheet.add_row [
                            "Finishers",charge.entries.where(result_description: "Complete").count,
                            "",
                            "International Teams",charge.entries.where(is_international: true).count
                        ],:style=>[head_cell,high_cell,nil,head_cell,high_cell]

          sheet.add_row [
                            "Gauntlet Finishers",charge.entries.where(result_gauntlet_guards: 3).count,
                            "",
                            "New Teams",charge.entries.where(is_newcomer: true).count
                        ],:style=>[head_cell,high_cell,nil,head_cell,high_cell]

          sheet.add_row [
                            "K Raised","K" + h.number_with_precision(charge.raised_kwacha, precision: 0, delimiter: ','),
                        ],:style=>[head_cell,high_cell]

          sheet.add_row [
                            "$ Raised","$" + h.number_with_precision(charge.raised_dollars, precision: 0, delimiter: ','),
                        ],:style=>[head_cell,high_cell]

          sheet.add_row
          sheet.add_row [Charge.awards(:net_distance) + ' - Shortest Net Distance',"",""],:style=>head_cell
          sheet.merge_cells(sheet.rows.last.cells[(0..2)])
          charge.entries.where("position_net_distance<=3 and result_description='Complete'").order(position_net_distance: :asc).each do |entry|
            sheet.add_row [
                              format_position(entry.position_net_distance),
                              entry.car_no.to_s + " " + entry.name,
                              (entry.dist_net.blank? ? '-' : h.number_with_precision(entry.dist_net/1000.0, precision: 2, delimiter: ',')) + 'km'
                          ],:style=>[main_cell,high_cell,main_cell]
          end

          sheet.add_row
          sheet.add_row [Charge.awards(:raised) + ' - Sponsorship Raised',"",""],:style=>head_cell
          sheet.merge_cells(sheet.rows.last.cells[(0..2)])
          charge.entries.where("position_raised<=3").order(position_raised: :asc).each do |entry|
            sheet.add_row [
                              format_position(entry.position_raised),
                              entry.car_no.to_s + " " + entry.name,
                              'K' + h.number_with_precision(entry.raised_kwacha, precision: 0, delimiter: ',')
                          ],:style=>[main_cell,high_cell,main_cell]
          end

          sheet.add_row
          sheet.add_row [Charge.awards(:distance) + ' - Shortest Distance',"",""],:style=>head_cell
          sheet.merge_cells(sheet.rows.last.cells[(0..2)])
          charge.entries.where("position_distance<=3").order(position_distance: :asc).each do |entry|
            sheet.add_row [
                              format_position(entry.position_distance),
                              entry.car_no.to_s + " " + entry.name,
                              entry.result_description + ' ' + h.number_with_precision(entry.dist_competition/1000.0, precision: 2, delimiter: ',') + 'km'
                          ],:style=>[main_cell,high_cell,main_cell]
          end

          sheet.add_row
          sheet.add_row [Charge.awards(:gauntlet) + ' - Shortest Gauntlet Distance',"",""],:style=>head_cell
          sheet.merge_cells(sheet.rows.last.cells[(0..2)])
          charge.entries.where("position_gauntlet<=3").order(position_gauntlet: :asc).each do |entry|
            sheet.add_row [
                              format_position(entry.position_gauntlet),
                              entry.car_no.to_s + " " + entry.name,
                              h.number_with_precision(entry.dist_withpentalty_gauntlet/1000.0, precision: 2, delimiter: ',') + 'km'
                          ],:style=>[main_cell,high_cell,main_cell]
          end

          sheet.add_row
          sheet.add_row [Charge.awards(:tsetse1) + ' - Shortest Distance Tsetse Line 1',"",""],:style=>head_cell
          sheet.merge_cells(sheet.rows.last.cells[(0..2)])
          charge.entries.where("position_tsetse1<=3").order(position_tsetse1: :asc).each do |entry|
            sheet.add_row [
                              format_position(entry.position_tsetse1),
                              entry.car_no.to_s + " " + entry.name,
                              h.number_with_precision(entry.dist_tsetse1/1000.0, precision: 2, delimiter: ',') + 'km'
                          ],:style=>[main_cell,high_cell,main_cell]
          end

          sheet.add_row
          sheet.add_row [Charge.awards(:tsetse2) + ' - Shortest Distance Tsetse Line 2',"",""],:style=>head_cell
          sheet.merge_cells(sheet.rows.last.cells[(0..2)])
          charge.entries.where("position_tsetse2<=3").order(position_tsetse2: :asc).each do |entry|
            sheet.add_row [
                              format_position(entry.position_tsetse2),
                              entry.car_no.to_s + " " + entry.name,
                              h.number_with_precision(entry.dist_tsetse2/1000.0, precision: 2, delimiter: ',') + 'km'
                          ],:style=>[main_cell,high_cell,main_cell]
          end

          if charge.entries.where(is_ladies: true).count>0
            sheet.add_row
            sheet.add_row [Charge.awards(:ladies) + ' - Shortest Distance for a Ladies Team',"",""],:style=>head_cell
            sheet.merge_cells(sheet.rows.last.cells[(0..2)])
            charge.entries.where("position_ladies<=3").order(position_ladies: :asc).each do |entry|
              sheet.add_row [
                                format_position(entry.position_ladies),
                                entry.car_no.to_s + " " + entry.name,
                                entry.result_description + ' ' + h.number_with_precision(entry.dist_competition/1000.0, precision: 2, delimiter: ',') + 'km'
                            ],:style=>[main_cell,high_cell,main_cell]
            end
          end

          if charge.entries.where(is_bikes: true).count>0
            sheet.add_row
            sheet.add_row [Charge.awards(:bikes) + ' - Shortest Distance for a Bike Team',"",""],:style=>head_cell
            sheet.merge_cells(sheet.rows.last.cells[(0..2)])
            charge.entries.where("position_bikes<=3").order(position_bikes: :asc).each do |entry|
              sheet.add_row [
                                format_position(entry.position_bikes),
                                entry.car_no.to_s + " " + entry.name,
                                entry.result_description + ' ' + h.number_with_precision(entry.dist_competition/1000.0, precision: 2, delimiter: ',') + 'km'
                            ],:style=>[main_cell,high_cell,main_cell]
            end
          end

          if charge.entries.where(is_bikes: true).count>0
            sheet.add_row
            sheet.add_row ['Shortest Net Distance for a Bike Team',"",""],:style=>head_cell
            sheet.merge_cells(sheet.rows.last.cells[(0..2)])
            charge.entries.where("position_net_bikes<=3").order(position_net_bikes: :asc).each do |entry|
              sheet.add_row [
                                format_position(entry.position_net_bikes),
                                entry.car_no.to_s + " " + entry.name,
                                h.number_with_precision(entry.dist_competition/1000.0, precision: 2, delimiter: ',') + 'km'
                            ],:style=>[main_cell,high_cell,main_cell]
            end
          end

          if charge.entries.where(is_newcomer: true).count>0
            sheet.add_row
            sheet.add_row ['Shortest Distance for a New Team',"",""],:style=>head_cell
            sheet.merge_cells(sheet.rows.last.cells[(0..2)])
            charge.entries.where("position_newcomer<=3").order(position_newcomer: :asc).each do |entry|
              sheet.add_row [
                                format_position(entry.position_newcomer),
                                entry.car_no.to_s + " " + entry.name,
                                entry.result_description + ' ' + h.number_with_precision(entry.dist_competition/1000.0, precision: 2, delimiter: ',') + 'km'
                            ],:style=>[main_cell,high_cell,main_cell]
            end
          end

          if charge.entries.where(is_international: true).count>0
            sheet.add_row
            sheet.add_row ['Shortest Distance for an International Team',"",""],:style=>head_cell
            sheet.merge_cells(sheet.rows.last.cells[(0..2)])
            charge.entries.where("position_international<=3").order(position_international: :asc).each do |entry|
              sheet.add_row [
                                format_position(entry.position_international),
                                entry.car_no.to_s + " " + entry.name,
                                entry.result_description + ' ' + h.number_with_precision(entry.dist_competition/1000.0, precision: 2, delimiter: ',') + 'km'
                            ],:style=>[main_cell,high_cell,main_cell]
            end
          end

          unless charge.spirit_name.blank?
            sheet.add_row
            sheet.add_row [Charge.awards(:spirit) + ' - Spirit of the Charge',"","","",""],:style=>head_cell
            sheet.merge_cells(sheet.rows.last.cells[(0..4)])
            sheet.add_row [charge.spirit_name,charge.spirit_description,"","",""],:style=>[high_wrap,main_wrap,main_cell,main_cell,main_cell],:height=>50
            sheet.merge_cells(sheet.rows.last.cells[(1..4)])
          end

          unless charge.shafted_entry.nil?
            sheet.add_row
            sheet.add_row ['Properly Shafted Award',"","","",""],:style=>head_cell
            sheet.merge_cells(sheet.rows.last.cells[(0..4)])
            sheet.add_row [charge.shafted_entry.name,charge.shafted_description,"","",""],:style=>[high_wrap,main_wrap,main_cell,main_cell,main_cell],:height=>50
            sheet.merge_cells(sheet.rows.last.cells[(1..4)])
          end

          unless charge.best_guard.nil?
            sheet.add_row
            sheet.add_row ['Best Checkpoint Award',"","","",""],:style=>head_cell
            sheet.merge_cells(sheet.rows.last.cells[(0..4)])
            sheet.add_row [charge.best_guard.name,"","","",""],:style=>high_cell
            sheet.merge_cells(sheet.rows.last.cells[(0..4)])
          end

          sheet.column_info.each do |info|
            info.width = 17
          end
        end

        wb.add_worksheet(:name => "Teams") do |sheet|
          sheet.add_row [charge.long_name],:style => title_cell
          sheet.add_row ["Teams"],:style => sub_title_cell
          sheet.add_row
          sheet.add_row ["","","","","","","","","","Competition Distance","","","","","Gauntlet","Positions","","","","",""], :style => head_cell
          sheet.merge_cells(sheet.rows.last.cells[(0..7)])
          sheet.merge_cells(sheet.rows.last.cells[(8..11)])
          sheet.merge_cells(sheet.rows.last.cells[(14..19)])
          sheet.add_row ["Team No", "Name","Type", "Start","End","K","$","Result","Net Distance","Overall","Gauntlet","Tsetse Line 1","Tsetse Line 2","Penalties","Actual","Net Distance","Funds Raised","Distance","Gauntlet","Tsetse Line 1","Tsetse Line 2"], :style => head_cell

          charge.entries.order(:car_no).each do |entry|
            sheet.add_row [
                entry.car_no,
                entry.team.long_name,
                entry.types_description,
                entry.start_guard.nil? ? '' : entry.start_guard.name,
                entry.end_time.nil? ? '' : formattime(entry.end_time),
                (entry.raised_kwacha.nil? ? '  -' : h.number_with_precision(entry.raised_kwacha, precision: 0)),
                (entry.raised_dollars.nil? ? '  -' : h.number_with_precision(entry.raised_dollars, precision: 0)),
                entry.result,
                entry.dist_net.nil? ? '' : h.number_with_precision(entry.dist_net/1000.0, precision: 2),
                entry.dist_competition.nil? ? '-' : h.number_with_precision(entry.dist_competition/1000.0, precision: 2),
                (entry.dist_gauntlet.nil?  ? '' : h.number_with_precision(entry.dist_multiplied_gauntlet/1000.0, precision: 2)),
                entry.dist_tsetse1.blank? ? '' : h.number_with_precision(entry.dist_tsetse1/1000.0, precision: 2),
                entry.dist_tsetse2.blank? ? '' : h.number_with_precision(entry.dist_tsetse2/1000.0, precision: 2),
                h.number_with_precision((entry.dist_penalty_gauntlet+entry.dist_penalty_nongauntlet)/1000.0, precision: 2),
                (entry.dist_gauntlet.nil? ? '' : h.number_with_precision(entry.dist_gauntlet/1000.0, precision: 2)),
                entry.position_net_distance,
                entry.position_raised,
                entry.position_distance,
                entry.position_gauntlet,
                entry.position_tsetse1,
                entry.position_tsetse2
                          ], :style=>[high_cell,high_cell,main_cell,main_cell,main_cell,main_cell,main_cell,main_cell,main_cell,main_cell,main_cell,main_cell,main_cell,main_cell,main_cell,main_cell,main_cell,main_cell,main_cell,main_cell,main_cell]
          end
          sheet.column_info[8].width=7
          sheet.column_info.first.width = 8.75
        end

        wb.add_worksheet(:name => "Team Details") do |sheet|
          sheet.add_row [charge.long_name],:style => title_cell
          sheet.add_row ["Team Details"],:style => sub_title_cell
          sheet.add_row

          charge.entries.order(:car_no).each do |entry|
            sheet.add_row [entry.car_no,entry.name,"","","",entry.result_description,"","",""],:style=>head_cell
            sheet.merge_cells(sheet.rows.last.cells[(1..4)])
            sheet.merge_cells(sheet.rows.last.cells[(5..8)])

            sheet.add_row ["No","From","To","Gauntlet","Out","In","Time Mins","Distance","Position"],:style=>high_cell

            entry.entry_legs.order(:leg_number).each do |entry_leg|
              sheet.add_row [
                entry_leg.leg_number,
                entry_leg.checkin1.guard.name,
                entry_leg.checkin2.guard.name,
                entry_leg.leg.is_gauntlet ? 'yes' : '',
                formattime(entry_leg.checkin1.checkin_timestamp),
                formattime(entry_leg.checkin2.checkin_timestamp),
                entry_leg.elapsed_s/60,
                h.number_with_precision(entry_leg.distance_m/1000.0, precision: 2),
                entry_leg.position.to_s + ' of ' + entry_leg.leg.entries.count.to_s
              ],:style=>main_cell
            end
            sheet.add_row
          end
          sheet.column_info.first.width = 8.75
        end

        wb.add_worksheet(:name => "Legs") do |sheet|
          sheet.add_row [charge.long_name],:style => title_cell
          sheet.add_row ["Legs"],:style => sub_title_cell
          sheet.add_row

          charge.legs.order(is_gauntlet: :desc, is_tsetse: :desc).each do |leg|
            sheet.add_row [leg.guard1.sponsor.name + ' to ' + leg.guard2.sponsor.name + (leg.is_gauntlet ? ' (Gauntlet)' : '') + (leg.is_tsetse ? '(Tsetse line)' : ''),"","","","","","",""],:style=>head_cell
            sheet.merge_cells(sheet.rows.last.cells[(0..7)])
            sheet.add_row ["Position","Team No","Team","Distance km","Multiple x","From","To","Time min"],:style=>high_cell

            leg.entry_legs.order(distance_m: :asc).each_with_index do |entry_leg,i|
              sheet.add_row [
                entry_leg.position,
                entry_leg.entry.car_no,
                entry_leg.entry.name,
                h.number_with_precision(entry_leg.distance_m/1000.0, precision: 2).to_s,
                h.number_with_precision(entry_leg.distance_m / (1.0 * leg.distance_m),precision:2).to_s + 'x',
                formattime(entry_leg.checkin1.checkin_timestamp),
                formattime(entry_leg.checkin2.checkin_timestamp),
                (entry_leg.elapsed_s/60).to_s
              ],:style=>main_cell
            end

            sheet.add_row
          end
          sheet.column_info.first.width = 8.75
        end


        p.serialize('public/system/charges/xlsx/ElephantCharge_' + charge.ref + '.xlsx')

      end
  end

  class Helpers
    include ActionView::Helpers::NumberHelper
  end
end