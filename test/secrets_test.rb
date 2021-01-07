require 'test_helper'

class SecretsTest < Minitest::Test
  def test_equals_ignore_case
    sample_config = {
      "matcher"=>"equals-ignore-case", 
      "list"=>["key"]
    }
    
    subject = Instana::Secrets.new
    assert_equal 'http://example.com/?kEy=%3Credacted%3E', subject.remove_from_query('http://example.com/?kEy=abcde', sample_config)  
  end
  
  def test_equals
    sample_config = {
      "matcher"=>"equals", 
      "list"=>["key"]
    }
    
    subject = Instana::Secrets.new
    assert_equal 'http://example.com/?key=%3Credacted%3E', subject.remove_from_query('http://example.com/?key=abcde', sample_config)  
  end
  
  def test_contains_ignore_case
    sample_config = {
      "matcher"=>"contains-ignore-case", 
      "list"=>["key"]
    }
    
    subject = Instana::Secrets.new
    assert_equal 'http://example.com/?KEYy=%3Credacted%3E', subject.remove_from_query('http://example.com/?KEYy=abcde', sample_config)    
  end
  
  def test_contains
    sample_config = {
      "matcher"=>"contains", 
      "list"=>["key"]
    }
    
    subject = Instana::Secrets.new
    assert_equal 'http://example.com/?keymt=%3Credacted%3E', subject.remove_from_query('http://example.com/?keymt=abcde', sample_config)  
  end
  
  def test_regexp
    sample_config = {
      "matcher"=>"regex", 
      "list"=>["key"]
    }
    
    subject = Instana::Secrets.new
    assert_equal 'http://example.com/?key=%3Credacted%3E', subject.remove_from_query('http://example.com/?key=abcde', sample_config)  
  end
end