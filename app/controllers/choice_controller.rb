class ChoiceController < ApplicationController
  
  def new
    @classes = 'home add'
    
    @choice = Choice.new( :contest_type => params[:type] == 'measure' ? 'User_Ballot' : 'User_Candidate' )

    @config =  { :state => 'not' }.to_json

    render :template => 'choice/add.html.erb'
  end
  
  
  def create
    if current_user.nil?
      render :text => 'no'
    else
      @states = Choice.states
      @abvs = Choice.stateAbvs
      geography = [@abvs[ @states.index( params[:choice][:geography] ) ],'User',current_user.id.to_s,Time.now.to_i.to_s].join('_')
      
      if params[:choice][:contest_type] == 'User_Candidate'
        @choice = Choice.new( 
          :contest => params[:choice][:contest],  
          :geography => geography,
          :votes => params[:choice][:votes].to_i,
          :contest_type => params[:choice][:contest_type],
          :options_attributes => params[:choice][:options_attributes]
        )
      else
        params[:choice][:options_attributes].each{ |k,v| v[:blurb_source] = params[:choice][:blurb_source] }
        @choice = Choice.new( 
          :contest => params[:choice][:contest],
          :description => params[:choice][:description],
          :geography => geography,
          :contest_type => params[:choice][:contest_type],
          :options_attributes => params[:choice][:options_attributes]
        )
      end
      if @choice.save
        redirect_to contest_path( @choice.geography, @choice.contest.gsub(' ','_'))
      else
        redirect_to user_add_choice_path, :error => @choice.errors
      end
    end
  end

  
  def profile
    
    if params[:id].to_i(16).to_s(16) == params[:id]
      @user = User.find_by_id( params[:id].to_i(16).to_s(10).to_i(2).to_s(10) )
    else
      @user = User.find_by_profile( params[:id] )
    end


    raise ActionController::RoutingError.new('Could not find that user') if @user.nil? 

    @choices = @user.choices.uniq.sort_by{ |choice| [ ['Federal','State','County','Other','Ballot_Statewide','User_Candidate','User_Ballot'].index( choice.contest_type), choice.geography, choice.geography.slice(-3).to_i ]  }.each{ |c| c.prep current_user; c.addUserFeedback @user }
    @classes = 'profile home'
    @title = !@user.guide_name.nil? && !@user.guide_name.strip.empty? ? @user.guide_name : @user.name+'\'s Voter Guide'
    @type = 'Voter Guide'
    @message = !@user.description.nil? && !@user.guide_name.strip.empty? ? @user.description : 'A Voter Guide by '+@user.first_name+', powered by The Ballot.'
    @image = @user.memes.last.nil? ? nil : ENV['BASE']+meme_show_image_path( @user.memes.last.id )+'.png'

    result = {:state => 'profile', :user => @user.to_public(false) }

    @config = result.to_json
    @choices_json = @choices.to_json( Choice.to_json_conditions )

  end

  def state
    
    @choices = Choice.where('geography LIKE ?', params[:state]+'%' ).order("contest_type IN('Federal','State','County','Other','Ballot_Statewide','User_Candidate','User_Ballot' ) ASC").limit( 50 ).offset( params[:page] || 0 )

    raise ActionController::RoutingError.new('Could not find that state') if @choices.nil? 

    @choices = @choices.each{ |c| c.prep current_user }
    
    if params[:format] == 'json'
      render :json => @choices.to_json( Choice.to_json_conditions )
    else
      @types = Choice.where('geography LIKE ?', params[:state]+'%' ).select("DISTINCT( contest_type)").sort_by{|c| ['Federal','State','County','Other','Ballot_Statewide','User_Candidate','User_Ballot'].index( c.contest_type) }.map{ |c| c.contest_type }

      @states = Choice.states
      @stateAbvs = Choice.stateAbvs
    
      @state = @states[ @stateAbvs.index( params[:state] ) ]
    
      @classes = 'home state'
      @title = @state+'\'s Full Ballot'
      @type = 'Voter Guide'
      @message = @state+'\'s Full Ballot, powered by The Ballot.'
    
      result = {:state => 'state', :choices => @choices, :title => @title, :message => @message }
    
      @choices_json = @choices.to_json
    
      @config = result.to_json
    end
    
  end
  
  def show
    @choice = Choice.find_by_geography_and_contest(params[:geography],params[:contest].gsub('_',' '))

    raise ActionController::RoutingError.new('Could not find '+params[:contest].gsub('_',' ') ) if @choice.nil?

    @classes = 'single home'
    @title = @choice.contest
    @partial = @choice.contest_type.downcase.index('ballot').nil? ? 'candidate/front' : 'measure/front'
    @type = @partial == 'candidate/front' ? 'Elected Office' : 'Ballot Measure'
    @message = @partial == 'measure/front' ? @choice.description : 'An election for '+@choice.contest+' between '+@choice.options.map{|o| o.name+'('+( o.party || '' )+')' }.join(', ')

    result = {:state => 'single', :choices => [ @choice ].each{ |c| c.prep current_user } }

    @config = result.to_json( Choice.to_json_conditions )

  end

  def index
    
    cicero = Cicero
    
    districts = params['q'].nil? ? cicero.find(params['l'], params[:address] ) : params['q'].split('|')
    
    unless districts.nil?
      @choices = Choice.find_by_districts( districts ).each{ |c| c.prep current_user }
    end
    
    if !params[:address_text].nil? && !params[:address_text].empty?
      if current_user
        current_user.address = params[:address_text]
        current_user.match = cicero.match
        current_user.save
      else
        cookies['ballot_address_cache'] = params[:address_text]
      end
    end
    
    render :json => @choices.to_json( Choice.to_json_conditions )
  end

  def more
    choice = Choice.find_by_id(params[:id])
    @feedback = choice.more( params[:page], current_user )
    render :json => @feedback
  end
end
