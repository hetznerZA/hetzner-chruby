require 'unit_helper'

describe 'chruby', :type => :class do

  describe 'managing a bunch of things we shouldnt' do
    let(:params) { Hash.new }

    it 'creates a downloads directory?' do
      expect( subject ).to contain_file( '/opt/puppet_staging/downloads' )
    end

    it 'creates a sources directory?' do
      expect( subject ).to contain_file( '/opt/puppet_staging/sources' )
    end
  end
end
