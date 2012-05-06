# -*- coding: utf-8 -*-
class User < ActiveRecord::Base

  attr_accessible           :first_name, :last_name, :alias, :email, :create_account

  attr_accessor             :create_account
                            # Boolean, der vormerkt, ob dem (neuen) Benutzer ein Account hinzugefügt werden soll.

  validates_presence_of     :first_name, :last_name, :alias, :email
  validates_uniqueness_of   :alias, :if => Proc.new { |user| ! user.alias.blank? }
  validates_format_of       :email, :with => /^[a-z0-9_.-]+@[a-z0-9-]+\.[a-z.]+$/i, :if => Proc.new { |user| user.email }

  has_many                  :profile_fields, :autosave => true, dependent: :destroy

  has_one                   :user_account, autosave: true, inverse_of: :user, dependent: :destroy

  has_dag_links             link_class_name: 'DagLink', ancestor_class_names: %w(Page Group), descendant_class_names: %w(Page)
  has_dag_links             link_class_name: 'RelationshipDagLink', ancestor_class_names: %w(Relationship), descendant_class_names: %w(Relationship), prefix: 'relationships'

  is_navable

  before_save               :generate_alias_if_necessary, :capitalize_name, :write_alias_attribute
  after_save                Proc.new { |user| user.profile.save }
  before_save                :create_account_if_requested


  def name
    first_name + " " + last_name
  end

  # Diese Funktion gibt eine sinnvolle Beschriftung des Benutzers zurück, z.B. für die Beschriftung von Menüpunkten, 
  # die diesen Benutzer repräsentieren. Damit ist der Aufruf der gleiche wie etwa beim Page-Modell. 
  # <tt>@title = page.title</tt>, <tt>@title = user.title</tt>.
  # Die Funktion gibt *nicht* den akademischen Titel oder die Anrede des Benutzers zurück.
  def title
    name + "  " + aktivitaetszahl
  end

  def profile
    @profile = Profile.new( self ) unless @profile
    return @profile
  end

  def alias
    @alias = UserAlias.new( read_attribute( :alias ), :user => self ) unless @alias.kind_of? UserAlias
    return @alias
  end
  def alias=( a )
    @alias = a
    write_alias_attribute
  end

  def email
    profile.email
  end
  def email=( email )
    profile.email = email
  end

  def capitalize_name
    self.first_name.capitalize!
    self.last_name.capitalize! unless last_name.include?( " " ) # "de Silva"
    self.name
  end

  def user_account
    @account = super unless @account
    @account = build_user_account unless @account
    return @account
  end
  def user_account=( account )
    @account = account
    super account
  end

  def account
    user_account
  end

  def has_account?
    # Wenn der Account keine ID hat, dann existiert er nicht.
    not user_account.id.nil?
  end

  def deactivate_account
    user_account.destory
  end

  def relationships
    relationships_parent_relationships + relationships_child_relationships
  end

  # Versucht, einen Benutzer anhand eines login_strings zu identifizieren, der beim Anmelden eingegeben wird.
  # Das kann eine E-Mail-Adresse, ein Benutzername, Vor- und Zuname, etc. sein.
  def self.identify( login_string )
    UserIdentification.find_users login_string
  end

  def self.authenticate( login_string, password )
    UserAccount.authenticate login_string, password 
  end

  # Verbindungen (im Sinne des Wingolfs am Hochschulort), d.h. Bänder, die ein Mitglied trägt.
  def corporations
    if Group.wingolf_am_hochschulort
      return self.ancestor_groups & Group.wingolf_am_hochschulort.child_groups 
    else
      return []
    end
  end

  # Der Bezirksverband, dem der Benutzer zugeordnet ist.
  def bv
    bv_of_this_user = ( Bv.all & self.ancestor_groups ).first
    return bv_of_this_user.becomes Bv if bv_of_this_user
  end

  def aktivitaetszahl
    ( self.corporations.collect { |corporation| corporation.token } ).join( " " )
  end

  private

  def write_alias_attribute
    write_attribute :alias, @alias
  end

  def generate_alias_if_necessary
    self.alias.generate! if self.alias.blank?
  end

  def create_account_if_requested
    self.create_account = false if self.create_account == "0" # wegen checkbox, da 0 nach true transformieren würde.
    if self.create_account
      self.user_account.destroy if self.has_account?
      self.user_account = self.build_user_account
      self.user_account.generate
      self.create_account = false
      return self.user_account
    end
  end

end

