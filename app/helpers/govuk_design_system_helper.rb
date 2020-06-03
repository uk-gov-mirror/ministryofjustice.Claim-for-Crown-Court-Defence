# https://design-system.service.gov.uk/components/button/
# Example
# I have identified three different link types/classes
# plus, we may wish to have app specific style
# A helper based component
# Do we use `content_tag` or the specific rails helper (if available) to output the element
# to be discussed


module GovukDesignSystemHelper
  def govuk_link( body = nil, url = nil, type = nil, html_options = {} )
    classes = html_options[:class].present? ? html_options[:class].split(' ') : []
    html_options.merge!(class: classes.join(' '))
    # link_to body, url, html_options

    content_tag :a, url, html_options do
      body
    end
  end
end


# Usage
# = govuk_link 'BBC', 'https://www.bbc.co.uk', { class: 'app-specific second-class' }
