require File.dirname(__FILE__) + '/../test_helper'

class PageExtensionsTest < Test::Unit::TestCase
  test_helper :page
  
  def setup
    setup_page(make_page!("Root"))
    @page.slug, @page.breadcrumb = "/", "/"
    @page.save!

    @site = Site.create(:name => "Site A",
                        :domain => "^a\.", :base_domain => "a.example.com",
                        :position => 1, :homepage_id => @page.id)
  end

  def test_should_find_page_on_other_site
    Page.current_site = @site
    site_b = Site.create(:name => "Site B", :domain => "^b\.", :base_domain => "b.example.com")
    kid = make_kid!(site_b.homepage, "a_child")
    assert_equal kid, Page.find_by_url("b.example.com:/a_child")
  end

  # MultiSite tests, to make sure their functionality still works

  def test_should_override_url
    assert_respond_to @page, :url_with_sites
    assert_respond_to @page, :url_without_sites
    assert_equal "/", @page.url
    @page.slug = "some-slug"
    assert_equal "/", @page.url
  end
  
  def test_should_override_class_find_by_url
    assert_respond_to Page, :find_by_url_with_sites
    assert_respond_to Page, :find_by_url_without_sites
    assert_respond_to Page, :current_site
    assert_respond_to Page, :current_site=
    # Defaults should still work
    assert_nothing_raised {
      Page.current_site = nil
      assert_equal @page, Page.find_by_url("/")
    }
    # Now find a site-scoped page
    doc_page = make_kid!(@page, "documentation")
    assert_nothing_raised {
      Page.current_site = @site
      assert_equal @page, Page.find_by_url("/")
      assert_equal doc_page, Page.find_by_url("/documentation")
    }
    # Now try a site that has no homepage
    assert_raises(Page::MissingRootPageError) {
      site_b = Site.create(:name => "Site B", :domain => "^b\.", :base_domain => "b.example.com")
      Page.delete(site_b.homepage)
      site_b.homepage = nil
      Page.current_site = site_b
      Page.find_by_url("/")
    }
  end
  
  def test_should_nullify_site_homepage_id_on_destroy
    assert_not_nil @site.homepage_id
    @page.destroy
    assert_nil @site.reload.homepage_id
  end

  protected

  def setup_page(page)
    @page = page
    @context = PageContext.new(@page)
    @parser = Radius::Parser.new(@context, :tag_prefix => 'r')
    @page
  end

  def assert_parse_output(expected, input, msg=nil)
    output = @parser.parse(input)
    assert_equal expected, output, msg
  end

  def make_page!(title)
    p = Page.find_or_create_by_title(title)
    p.slug, p.breadcrumb = title.downcase, title
    p.parts.find_or_create_by_name("body")
    p.status_id = 100
    p.save!
    p
  end
  def make_kid!(page, title)
    kid = make_page!(title)
    page.children << kid
    page.save!
    kid
  end
  def make_kids!(page, *kids)
    kids.collect {|kid| make_kid!(page, kid) }
  end

end
