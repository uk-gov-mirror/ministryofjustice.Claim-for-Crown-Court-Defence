# Disable alerts during headless chrome run
#
require 'rack/injectable'
module Rack
  class NoPopups
    include Injectable

    DISABLE_POPUPS_HTML = <<~HTML.freeze
      <script type="text/javascript">
        window.alert = function() { };
        window.confirm = function() { return true; };
      </script>
    HTML

    private

    def fragment
      DISABLE_POPUPS_HTML
    end
  end
end
