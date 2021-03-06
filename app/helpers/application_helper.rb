module ApplicationHelper

end

def random_color
  r = rand(255).to_s(16)
  g = rand(255).to_s(16)
  b = rand(255).to_s(16)
  r, g, b = [r, g, b].map { |s| if s.size == 1 then '0' + s else s end }
  color = r + g + b
end

def format_position(pos)
  ret='1st' if pos==1
  ret='2nd' if pos==2
  ret='3rd' if pos==3
  ret=pos.to_s + 'th' if pos>3
  ret
end

def formattime(time)
  unless time.nil?
    time.strftime("%H:%M %p")
  else
    '-'
  end

end

class LabellingFormBuilder < ActionView::Helpers::FormBuilder

  def label_location(label,attribute,options)
    @template.content_tag "div", {class: "form-group row"} do
      label(label, {class: 'col-sm-4 col-form-label'}) +

          (@template.content_tag "div", {class: "col-sm-4"} do
            @template.text_field @object_name,attribute.to_s + "_longitude",{class: 'form-control',placeholder: 'Longitude'}
          end) +
          (@template.content_tag "div", {class: "col-sm-4"} do
            @template.text_field @object_name,attribute.to_s + "_latitude",{class: 'form-control',placeholder: 'Latitude'}
          end)
    end
  end

  def label_check_box(label,attribute,options)
    @template.content_tag "div", {class: "form-group row"} do
      label(label, {class: 'col-sm-4 col-form-label'}) +
          check_box(attribute,options)
    end
  end
  def check_box(attribute,options)
    @template.content_tag "div", {class: "col-sm-8"} do
      @template.content_tag "div", {class: "form-check"} do
        @template.content_tag "label", {class: "form-check-label"} do
          (super attribute,{class: 'form-check-input'}) + "yes / no"
        end
      end
    end
  end


  def label_select(label,attribute, select_options,options)
    @template.content_tag "div", {class: "form-group row"} do
      label(label, {class: 'col-sm-4 col-form-label'}) +
          select(attribute,select_options,options)
    end
  end
  def select(attribute,select_options,options)
    (@template.content_tag "div", {class: "col-sm-8"} do
      #@template.select_tag @object_name,attribute,select_options,options,{class: 'form-control'}
      super attribute,select_options,options,{class: 'form-control'}
    end)
  end

  def label_date_field(label,attribute, *args)
    @template.content_tag "div", {class: "form-group row"} do
      label(label, {class: 'col-sm-4 col-form-label'}) +
          date_field(attribute)
    end
  end
  def date_field(attribute)
    (@template.content_tag "div", {class: "col-sm-8"} do
      super attribute,{class: 'form-control'}
    end)
  end


  def label_time_field(label,attribute, *args)
    @template.content_tag "div", {class: "form-group row"} do
      label(label, {class: 'col-sm-4 col-form-label'}) +
          time_field(attribute)
    end
  end
  def time_field(attribute)
    (@template.content_tag "div", {class: "col-sm-8"} do
      super attribute,{class: 'form-control'}
    end)
  end


  def label_text_field(label,attribute, *args)
    @template.content_tag "div", {class: "form-group row"} do
      label(label, {class: 'col-sm-4 col-form-label'}) +
          text_field(attribute)
        end
  end
  def text_field(attribute)
    (@template.content_tag "div", {class: "col-sm-8"} do
      super attribute,{class: 'form-control'}
    end)
  end
end