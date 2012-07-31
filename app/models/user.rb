class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :omniauthable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me, 
    :image, :location, :name, :url, :first_name, :last_name, :feedback, :admin, :authentication_token, :guide_name, :fb

  
  # attr_accessible :title, :body
  has_many :feedback
  has_many :options, :through => :feedback
  has_many :choices, :through => :options

  
  attr_writer :profile
  
  def profile
    return '/'+self.to_url
  end
  
  def self.find_for_facebook_oauth(access_token, signed_in_resource=nil)
    data = access_token.extra.raw_info
    attributes = {
        :image => access_token.info.image, 
        :location => access_token.info.location, 
        :url => data.link,
        :name => data.name,
        :first_name => data.first_name,
        :last_name => data.last_name,
        :authentication_token => access_token.credentials.token,
        :fb => data.id
      }
    if user = self.find_by_email(data.email)
      user.update_attributes( attributes)
      user
    else # Create a user with a stub password. 
      attributes[:email] = data.email
      attributes[:password] = Devise.friendly_token[0,20]
      self.create!( attributes )
    end
  end
  
  def self.new_with_session(params, session)
    super.tap do |user|
      if data = session["devise.facebook_data"] && session["devise.facebook_data"]["extra"]["raw_info"]
        user.email = data["email"]
      end
    end
  end
  
  def to_url
    return self.id.to_s(2).to_i.to_s(16) unless self.new_record? # A simple way of creating funky looking URLs out of User IDs
    return nil
  end
  

end
