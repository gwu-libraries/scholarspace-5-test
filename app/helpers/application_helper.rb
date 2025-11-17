module ApplicationHelper

  # This is just used in stripping the "?locale=en" when setting the path to the 
  # pdf for pdfjs in 'hyrax/academic_documents/show.html.erb' 
  def without_params(input_str)
    input_str.include?('?') ? input_str[0...input_str.index('?')] : input_str
  end
end
