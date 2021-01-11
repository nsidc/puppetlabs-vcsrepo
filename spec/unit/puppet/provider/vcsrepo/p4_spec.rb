# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:vcsrepo).provider(:p4) do
  let(:resource) do
    Puppet::Type.type(:vcsrepo).new(name: 'test',
                                    ensure: :present,
                                    provider: :p4,
                                    path: '/tmp/vcsrepo')
  end

  let(:provider) { resource.provider }

  before :each do
    allow(Puppet::Util).to receive(:which).with('p4').and_return('/usr/local/bin/p4')
  end

  spec = {
    input: "Description: Generated by Puppet VCSrepo\nRoot: /tmp/vcsrepo\n\nView:\n",
    marshal: false,
  }

  describe 'creating' do
    context 'with source and revision' do
      it "executes 'p4 sync' with the revision" do
        resource[:source] = 'something'
        resource[:revision] = '1'
        ENV['P4CLIENT'] = 'client_ws1'

        expect(provider).to receive(:p4).with(['client', '-o', 'client_ws1']).and_return({})
        expect(provider).to receive(:p4).with(['client', '-i'], spec)
        expect(provider).to receive(:p4).with(['sync', resource.value(:source) + '@' + resource.value(:revision)])
        provider.create
      end
    end

    context 'without revision' do
      it "justs execute 'p4 sync' without a revision" do
        resource[:source] = 'something'
        ENV['P4CLIENT'] = 'client_ws2'

        expect(provider).to receive(:p4).with(['client', '-o', 'client_ws2']).and_return({})
        expect(provider).to receive(:p4).with(['client', '-i'], spec)
        expect(provider).to receive(:p4).with(['sync', resource.value(:source)])
        provider.create
      end
    end

    context 'when a client and source are not given' do
      it "executes 'p4 client'" do
        ENV['P4CLIENT'] = nil

        path = resource.value(:path)
        host = Facter.value('hostname')
        default = 'puppet-' + Digest::MD5.hexdigest(path + host)

        expect(provider).to receive(:p4).with(['client', '-o', default]).and_return({})
        expect(provider).to receive(:p4).with(['client', '-i'], spec)
        provider.create
      end
    end
  end

  describe 'destroying' do
    it 'removes the directory' do
      ENV['P4CLIENT'] = 'test_client'

      expect(provider).to receive(:p4).with(['client', '-d', '-f', 'test_client'])
      expect_rm_rf
      provider.destroy
    end
  end

  describe 'checking existence' do
    it 'checks for the directory' do
      expect(provider).to receive(:p4).with(['info'], marshal: false).and_return({})
      expect(provider).to receive(:p4).with(['where', resource.value(:path) + '/...'], raise: false).and_return({})
      provider.exists?
    end
  end

  describe 'checking the source property' do
    it "runs 'p4 where'" do
      resource[:source] = '//public/something'
      expect(provider).to receive(:p4).with(['where', resource.value(:path) + '/...'],
                                            raise: false).and_return('depotFile' => '//public/something')
      expect(provider.source).to eq(resource.value(:source))
    end
  end

  describe 'setting the source property' do
    it "calls 'create'" do
      resource[:source] = '//public/something'
      expect(provider).to receive(:create)
      provider.source = resource.value(:source)
    end
  end
end
