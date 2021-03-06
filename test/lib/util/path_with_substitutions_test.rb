require 'katello_test_helper'

module Katello
  module Util
    class PathWithSubstitutionsTest < ActiveSupport::TestCase
      def setup
        @el5_path = '/content/dist/rhel/server/5/$releasever/$basearch/os'
        @non_sub_path = '/content/dist/rhel/server/5/5Server/x86_64/os'
        @el8_path = '/content/dist/rhel8/8.0/x86_64/baseos/os/'
        @el8_layered_path = '/content/dist/layered/rhel8/x86_64/product'
        @el8_arch_misplaced = '/content/dist/rhel8/x86_64/product'
        @releasever_list = ['5Server', '5.8']
        @arch_list = ['x86_64', 'i386']
        @cdn = Katello::Resources::CDN::CdnResource.new('http://someurl/')
      end

      def test_substitutions_needed
        assert_equal ['releasever', 'basearch'], PathWithSubstitutions.new(@el5_path, {}).substitutions_needed
        assert_empty PathWithSubstitutions.new(@non_sub_path, {}).substitutions_needed
      end

      def test_substitutable?
        assert PathWithSubstitutions.new(@el5_path, {}).substitutable?
        refute PathWithSubstitutions.new(@non_sub_path, {}).substitutable?
      end

      def test_rhel_eight_substitutions
        el8_path_with_sub = PathWithSubstitutions.new(@el8_path, {})
        el8_layered_path_with_sub = PathWithSubstitutions.new(@el8_layered_path, {})
        el8_arch_misplaced_path_with_sub = PathWithSubstitutions.new(@el8_arch_misplaced, {})
        assert_equal el8_path_with_sub.substitutions["basearch"], "x86_64"
        assert_equal el8_layered_path_with_sub.substitutions["basearch"], "x86_64"
        assert_equal el8_arch_misplaced_path_with_sub.substitutions["basearch"], "x86_64"
      end

      def test_no_basearch_substitutions
        relver = 'rhel8'
        arch = 'x86_64'
        no_base_arch_path = "/content/dist/$releasever/#{arch}/product"
        no_base_arch = PathWithSubstitutions.new(no_base_arch_path, "releasever" => relver)
        assert_equal no_base_arch.substitutions["basearch"], arch
        assert_equal no_base_arch.substitutions["releasever"], relver
      end

      def test_resolve_substitutions_releasever
        path = PathWithSubstitutions.new(@el5_path, {})
        @cdn.expects(:fetch_substitutions).with('/content/dist/rhel/server/5/').returns(@releasever_list)

        resolved = path.resolve_substitutions(@cdn)

        assert_equal 2, resolved.count
        assert_equal '/content/dist/rhel/server/5/5Server/$basearch/os', resolved[0].path
        assert_equal '/content/dist/rhel/server/5/5.8/$basearch/os', resolved[1].path
        assert_equal resolved[0].substitutions, 'releasever' => '5Server'
        assert_equal resolved[1].substitutions, 'releasever' => '5.8'
      end

      def test_resolve_substitutions_arch
        release_resolved_path = '/content/dist/rhel/server/5/5Server/$basearch/os'
        path = PathWithSubstitutions.new(release_resolved_path, 'releasever' => '5Server')
        @cdn.expects(:fetch_substitutions).with('/content/dist/rhel/server/5/5Server/').returns(@arch_list)

        resolved = path.resolve_substitutions(@cdn)

        assert_equal 2, resolved.count
        assert_equal '/content/dist/rhel/server/5/5Server/x86_64/os', resolved[0].path
        assert_equal '/content/dist/rhel/server/5/5Server/i386/os', resolved[1].path
        assert_equal resolved[0].substitutions, 'releasever' => '5Server', 'basearch' => 'x86_64'
        assert_equal resolved[1].substitutions, 'releasever' => '5Server', 'basearch' => 'i386'
      end

      def test_unused_substitutions
        assert_equal ['foo'], PathWithSubstitutions.new(@el5_path, 'foo' => 'bar').unused_substitutions
        assert_empty PathWithSubstitutions.new(@el5_path, 'basearch' => 'x86_64').unused_substitutions
      end

      def test_apply_substitutions
        assert_equal '/content/dist/rhel/server/5/$releasever/x86_64/os',
                     PathWithSubstitutions.new(@el5_path, 'basearch' => 'x86_64').apply_substitutions
      end
    end
  end
end
