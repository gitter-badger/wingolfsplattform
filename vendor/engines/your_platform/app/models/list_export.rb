# This class helps to export data to CSV, XLS and possibly others.
#
# Example:
#
#     class PeopleController
#       def index
#         # ...
#         format.xls do
#           send_data ListExport.new(@people, :birthday_list).to_xls
#         end
#       end
#     end
#
# The following ressources might be helpful.
#
#   * https://github.com/splendeo/to_xls
#   * https://github.com/zdavatz/spreadsheet
#   * Formatting xls: http://scm.ywesee.com/?p=spreadsheet/.git;a=blob;f=lib/spreadsheet/format.rb
#   * to_xls gem example: http://stackoverflow.com/questions/15600987/
# 
class ListExport
  attr_accessor :data, :preset, :csv_options
  
  def initialize(initial_data, initial_preset = nil)
    @data = initial_data; @preset = initial_preset
    @csv_options =  { col_sep: ';', quote_char: '"' }
    raise_error_if_data_is_not_valid
    @data = processed_data
    @data = sorted_data
  end
  
  def columns
    case preset.to_s
    when 'birthday_list'
      [:last_name, :first_name, :cached_name_affix, :cached_localized_birthday_this_year, 
        :cached_localized_date_of_birth, :cached_current_age]
    when 'address_list'
      #
      # TODO: Add the street as a separate column.
      # This was requested at the meeting at Gernsbach, Jun 2014.
      #
      [:last_name, :first_name, :cached_name_affix, :cached_postal_address_with_name_surrounding,
        :cached_postal_address, :cached_localized_postal_address_updated_at, 
        :cached_postal_address_postal_code, :cached_postal_address_town,
        :cached_postal_address_country, :cached_postal_address_country_code,
        :cached_personal_title, :cached_address_label_text_above_name, :cached_address_label_text_below_name,
        :cached_address_label_text_before_name, :cached_address_label_text_after_name]
    when 'phone_list'
      [:last_name, :first_name, :cached_name_affix, :phone_label, :phone_number]
      # One row per phone number, not per user. See `#processed_data`.
    when 'email_list'
      [:last_name, :first_name, :cached_name_affix, :email_label, :email_address]
      # One row per email, not per user. See `#processed_data`.
    when 'member_development'
      [:last_name, :first_name, :cached_name_affix, :cached_localized_date_of_birth, :cached_date_of_death] + @leaf_group_names
    else
      # This name_list is the default.
      [:last_name, :first_name, :cached_name_affix, :cached_personal_title, :cached_academic_degree]
    end
  end
  
  def headers
    columns.collect do |column|
      if column.kind_of? Symbol
        I18n.translate column.to_s.gsub('cached_', '').gsub('localized_', '')
      else
        column
      end
    end
  end
  
  def processed_data
    if preset.to_s.in?(['birthday_list', 'address_list', 'phone_list', 'email_list']) && @data.kind_of?(Group)
      # To be able to generate lists from Groups as well as search results, these presets expect 
      # an Array of Users as data. If a Group is given instead, just take the group members as data.
      #
      @data = @data.members
    end
    
    # Make the extended methods available that are defined below.
    #
    if @data.respond_to?(:first) && @data.first.kind_of?(User)
      @data = @data.collect { |user| user.becomes(ListExportUser) }
    end

    case preset.to_s
    when 'phone_list'
      #
      # For the phone_list, one row represents one phone number of a user,
      # not a user. I.e. there can be serveral rows per user.
      #
      data.collect { |user|
        user.phone_profile_fields.collect { |phone_field| {
          :last_name          => user.last_name,
          :first_name         => user.first_name,
          :cached_name_affix  => user.cached_name_affix,
          :phone_label        => phone_field.label,
          :phone_number       => phone_field.value
        } }
      }.flatten
    when 'email_list'
      #
      # For the email list, one row represents one email address of a user,
      # not a user. I.e. there can be several rows per user.
      #
      data.collect { |user|
        user.profile_fields.where(type: 'ProfileFieldTypes::Email').collect { |email_field| {
          :last_name          => user.last_name,
          :first_name         => user.first_name,
          :cached_name_affix  => user.cached_name_affix,
          :email_label        => email_field.label,
          :email_address      => email_field.value
        } }
      }.flatten
    when 'member_development'
      #
      # From data being a Group, this generates one line per user. Several columns are
      # created based on the leaf groups of the given Group.
      #
      @group = @data
      @group = @group.becomes(ListExportGroup)
      @leaf_groups = @group.cached_leaf_groups
      # FIXME: The leaf groups should not return any officer group. Make this fix unneccessary:
      @leaf_groups -= @group.descendant_groups.where(name: ['officers', 'Amtsträger'])
      # /FIXME
      @leaf_group_names = @leaf_groups.collect { |group| group.name }
      @leaf_group_ids = @leaf_groups.collect { |group| group.id }
      
      @group.members.collect do |user|
        user = user.becomes(ListExportUser)
        row = {
          :last_name                      => user.last_name,
          :first_name                     => user.first_name,
          :cached_name_affix              => user.cached_name_affix,
          :cached_localized_date_of_birth => user.cached_localized_date_of_birth,
          :cached_date_of_death           => user.cached_date_of_death
        }
        @leaf_groups.each do |leaf_group|
          membership = user.links_as_child_for_groups.where(ancestor_id: leaf_group.id).first
          date = membership.try(:valid_from).try(:to_date)
          localized_date = I18n.localize(date) if date
          row[leaf_group.name] = (localized_date || '')
        end
        row
      end
    else
      data
    end
  end

  def sorted_data
    case preset.to_s
    when 'birthday_list'
      data.sort_by do |user|
        user.cached_date_of_birth.try(:strftime, "%m-%d") || ''
      end
    when 'address_list', 'name_list'
      data.sort_by do |user|
        user.last_name + user.first_name
      end
    when 'phone_list', 'email_list'
      data.sort_by do |user_hash|
        user_hash[:last_name] + user_hash[:first_name]
      end
    else
      data
    end
  end
  
  def raise_error_if_data_is_not_valid
    case preset.to_s
    when 'birthday_list', 'address_list', 'phone_list', 'email_list', 'name_list'
      data.kind_of?(Group) || data.first.kind_of?(User) || raise("Expecing Group or list of Users as data in ListExport with the preset '#{preset}'.")
    when 'member_development'
      data.kind_of?(Group) || raise('The member_development list can only be generated for a Group, not an Array of Users.')
    end    
  end
  
  def to_csv
    CSV.generate(csv_options) do |csv|
      csv << headers
      data.each do |row|
        csv << columns.collect do |column_name|
          if row.respond_to? :values
            row[column_name]
          elsif row.respond_to? column_name
            row.try(:send, column_name) 
          else
            raise "Don't know how to access the given attribute or value. Trying to access '#{column_name}' on '#{row}'."
          end
        end
      end
    end
  end
  
  def to_xls
    header_format = {weight: 'bold'}
    @data = @data.collect { |hash| HashWrapper.new(hash) } if @data.first.kind_of? Hash
    @data.to_xls(columns: columns, headers: headers, header_format: header_format)
  end
  
  def to_s
    to_csv
  end
end

class HashWrapper
  def initialize(hash)
    @hash = hash
  end
  
  # This is a workaround for the to_xls gem, which requires to access the attributes
  # by method in order to write the columns in the correct order.
  #
  def method_missing(method_name, *args, &block)  
    @hash[method_name] || @hash[method_name.to_sym]
  end
end

# TODO: Refactor this:
#   Whenever it makes sense, these methods should live inside the regular User class.
#   But this should be done after introducing the new model caching mechanism.
#
require 'user'
class ListExportUser < User
  
  # Gerneral Attributes
  #
  def cached_personal_title
    cached(:personal_title)
  end
  def cached_academic_degree
    cached(:academic_degree)
  end
  
  # Birthday, Date of Birth, Date of Death
  #
  def cached_date_of_birth
    cached(:date_of_birth)
  end
  def cached_name_affix
    cached(:name_affix)
  end
  def cached_birthday_this_year
    cached(:birthday_this_year)
  end
  def cached_date_of_death
    cached(:date_of_death)
  end
  def cached_age
    cached(:age)
  end
  def cached_current_age
    cached_age
  end
  def cached_localized_birthday_this_year
    I18n.localize cached_birthday_this_year if cached_birthday_this_year
  end
  def cached_localized_date_of_birth
    I18n.localize cached_date_of_birth if cached_date_of_birth
  end
  
  # Address
  #
  def cached_postal_address
    cached(:postal_address)
  end
  def cached_address_label
    cached(:address_label)
  end
  def cached_postal_address_with_name_surrounding
    cached_address_label.postal_address_with_name_surrounding
  end
  def cached_postal_address_updated_at
    cached(:postal_address_updated_at)
  end
  def cached_localized_postal_address_updated_at
    I18n.localize cached_postal_address_updated_at if cached_postal_address_updated_at
  end
  def cached_postal_address_postal_code
    cached_address_label.postal_code
  end
  def cached_postal_address_town
    cached_address_label.city
  end
  def cached_postal_address_country
    cached_address_label.country
  end
  def cached_postal_address_country_code
    cached_address_label.country_code
  end
  def cached_address_label_text_above_name
    cached_address_label.text_above_name
  end
  def cached_address_label_text_below_name
    cached_address_label.text_below_name
  end
  def cached_address_label_text_before_name
    cached_address_label.name_prefix
  end
  def cached_address_label_text_after_name
    cached_address_label.name_suffix
  end
end

class ListExportGroup < Group
  def cached_leaf_groups
    cached(:leaf_groups)
  end
end