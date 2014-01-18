require 'spec_helper'

describe 'chruby' do

  describe 'managing a bunch of things we shouldnt' do
    let(:params) { Hash.new }

    it 'creates a downloads directory?' do
      expect( subject ).to contain_file( '/opt/puppet_staging/downloads' )
    end
  end
end
