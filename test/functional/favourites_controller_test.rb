require 'test_helper'

class FavouritesControllerTest < ActionController::TestCase
  
  include AuthenticatedTestHelper
  include FavouritesHelper
  
  fixtures :users, :favourites, :projects, :people, :institutions
  
  def setup
    login_as(:quentin)
  end
  
  test "can add valid favourite" do
    project = projects(:one)    

    fav=Favourite.find_by_resource_type_and_resource_id("Project",project.id)
    assert_nil fav
    
    xml_http_request(:post, :add, {:resource_type => project.class.name, :resource_id => project.id})
    
    assert_response :created
    
    fav=Favourite.find_by_resource_type_and_resource_id("Project",project.id)
    assert_not_nil fav
  end

  test "can't add duplicate favourite" do
    project = projects(:two)    

    #sanity check that it does actually already exist
    fav=Favourite.find_by_resource_type_and_resource_id_and_user_id("Project",project.id,users(:quentin).id)
    assert_not_nil fav, "The project with id 2 should already exist for quentin"

    xml_http_request(:post, :add, {:resource_type => project.class.name, :resource_id => project.id})
    
    assert_response :unprocessable_entity
  end

  test "can add favourite search query" do
    assert_difference("Favourite.count",1) do
      assert_difference("SavedSearch.count",1) do
        xml_http_request(:post,:add, {:resource_type => 'SavedSearch',:search_query=>"fred bloggs",:search_type=>"All"})
      end
    end
    assert_response :success
    fav=Favourite.last
    assert_equal "SavedSearch",fav.resource_type
    ss=fav.resource
    assert_equal "fred bloggs",ss.search_query
    assert_equal "All",ss.search_type
    assert !ss.include_external_search
  end

  test "can add favourite external search query" do
    assert_difference("Favourite.count",1) do
      assert_difference("SavedSearch.count",1) do
        xml_http_request(:post,:add, {:resource_type => 'SavedSearch',:search_query=>"fred bloggs",:search_type=>"All",:include_external_search=>"1"})
      end
    end
    assert_response :success
    fav=Favourite.last
    assert_equal "SavedSearch",fav.resource_type
    ss=fav.resource
    assert_equal "fred bloggs",ss.search_query
    assert_equal "All",ss.search_type
    assert ss.include_external_search

  end

  test "can't add duplicate favourite search query" do
    ss=Factory :saved_search
    login_as(ss.user)
    assert_no_difference("Favourite.count") do
      assert_no_difference("SavedSearch.count") do
        xml_http_request(:post,:add, {:resource_type => 'SavedSearch',:search_query=>"cheese",:search_type=>"All"})
      end
    end
    assert_response :unprocessable_entity
  end

  test "can add duplicate favourite search query with different type" do
    ss=Factory :saved_search
    login_as(ss.user)
    assert_difference("Favourite.count",1) do
      assert_difference("SavedSearch.count",1) do
        xml_http_request(:post,:add, {:resource_type => 'SavedSearch',:search_query=>"cheese",:search_type=>"Assays"})
      end
    end
    assert_response :success
  end

  test "can add duplicate favourite search query with different external flag" do
    ss=Factory :saved_search
    login_as(ss.user)
    assert_difference("Favourite.count",1) do
      assert_difference("SavedSearch.count",1) do
        xml_http_request(:post,:add, {:resource_type => 'SavedSearch',:search_query=>"cheese",:search_type=>"All",:include_external_search=>"1"})
      end
    end
    assert_response :success
  end

  test "can delete saved search" do
    Favourite.destroy_all
    SavedSearch.destroy_all
    ss=Factory :saved_search
    login_as(ss.user)

    f=Favourite.create(:resource=>ss,:user=>ss.user)

    assert_not_nil Favourite.find_by_resource_type("SavedSearch")
    assert_not_nil SavedSearch.find_by_search_query("cheese")
    assert_not_nil Favourite.find_by_id(f.id)

    assert_difference("Favourite.count",-1) do
      assert_difference("SavedSearch.count",-1) do
        xml_http_request(:delete,:delete,{:id=>f.id})
      end
    end
    assert_response :success
    
    assert_nil Favourite.find_by_resource_type("SavedSearch")
    assert_nil SavedSearch.find_by_search_query("cheese")
    assert_nil Favourite.find_by_id(f.id)
  end

  test "can delete favourite" do
    project = projects(:two)  
    xml_http_request(:delete, :delete, {:id=>favourites(:project_fav).id})
    assert_response :success
    fav=Favourite.find_by_resource_type_and_resource_id_and_user_id("Project",project.id,users(:quentin).id)
    assert_nil fav, "Favourite should have been destroyed"
  end

  test "shouldn't add invalid resource" do
    fav=Favourite.find_by_resource_type_and_resource_id("DataFile",-1)
    assert_nil fav
    
    xml_http_request(:post, :add, {:resource_type => 'DataFile', :resource_id => -1})
    
    assert_response :unprocessable_entity
    
    fav=Favourite.find_by_resource_type_and_resource_id("DataFile",-1)
    assert_nil fav
  end

  # NOTE: Testing for invalid methods (GET, PUT etc. when only POST is allowed) produces false positives, but in the actual
  #  app it works as it should.

end
