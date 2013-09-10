# This extends the your_platform ProfileFieldTypes module.
require_dependency YourPlatform::Engine.root.join( 'app/models/profile_field_types' ).to_s


# Template
#
# class SpecialProfileField < ProfileField
#   def self.model_name; ProfileField.model_name; end#
#
#   def display_html
#     self.value
#   end
#
# end


module ProfileFieldTypes

  # Address Information
  # ==========================================================================================

  class Address

    attr_accessible :wingolfspost

    # This method returns the Bv associated with the given address.
    #
    def bv
      geo_location.bv if geo_location
    end

    # The html output method is overridden here, in order to display the bv as well.
    #
    def display_html
      text_to_display = self.value

      if self.bv
        text_to_display = "
        <p>#{text_to_display}</p>
        <p class=\"address_is_in_bv\">
          (#{I18n.translate( :address_is_in_the )} " +
          ActionController::Base.helpers.link_to( self.bv.name,
                                                  Rails.application.routes.url_helpers.group_path( self.bv.becomes( Group ) ) ) +
          ")
        </p>"

        # more infos on how to use the link_to helper in models:
        # http://stackoverflow.com/questions/4713571/view-helper-link-to-in-model-class

      end

      ActionController::Base.helpers.simple_format( text_to_display )
    end
    
    # Allow to mark the address as primary postal address.
    #
    def wingolfspost
      self.postal_address
    end
    def wingolfspost=(new_wingolfspost)
      self.postal_address = new_wingolfspost
    end
    def wingolfspost?
      self.wingolfspost
    end

  end


  # Studies Information
  # ==========================================================================================

  class Study < ProfileField
    def self.model_name; ProfileField.model_name; end

    has_child_profile_fields :from, :to, :university, :subject, :specialization

    # If the single study has no label, just say 'Study'.
    #
    def label
      super || I18n.translate( :study, default: "Study" )
    end

  end

  
  # Wingolf-spezifisch
  # ==========================================================================================

  class Klammerung < ProfileField
    def self.model_name; ProfileField.model_name; end
    
  end

end
