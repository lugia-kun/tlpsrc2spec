require "./spec_helper"
require "./test"

include TLpsrc2spec

TEST_LICENSES = [
  TLpsrc2spec::TLPDB::License::GPL_v1,
  TLpsrc2spec::TLPDB::License::LGPL,
  TLpsrc2spec::TLPDB::License::LPPL_v1_3c,
]
TEST2_LICENSES = [
  TLpsrc2spec::TLPDB::License::GPL_v1,
  TLpsrc2spec::TLPDB::License::LPPL_v1_3b,
  TLpsrc2spec::TLPDB::License::BSD,
  TLpsrc2spec::TLPDB::License::PublicDomain,
]

describe StringCase do
  it "expands" do
    test = StringCase::Single.new("teststr")
    ret = StringCase.strcase(complete: true) do
      case test
      when "te"
        1
      when "test"
        2
      when "testxxxx"
        3
      else
        4
      end
    end
    ret.should eq(4)

    test.pos = 0
    ret = StringCase.strcase do
      case test
      when "te"
        1
      when "test"
        2
      when "testxxxx"
        3
      else
        4
      end
    end
    ret.should eq(2)
    test.gets_to_end.should eq("str")

    test = StringCase::Single.new("TeSt")
    ret = StringCase.strcase(complete: true) do
      case test
      when "te"
        1
      when "test"
        2
      when "testxxxx"
        3
      else
        4
      end
    end
    ret.should eq(4)

    test.pos = 0
    ret = StringCase.strcase(case_insensitive: true) do
      case test
      when "te"
        1
      when "testaa"
        2
      when "testxxxx"
        3
      else
        4
      end
    end
    ret.should eq(1)

    test.pos = 0
    ret = StringCase.strcase(case_insensitive: true) do
      case test
      when "te"
        1
      when "test"
        2
      when "testxxxx"
        3
      else
        4
      end
    end
    ret.should eq(2)

    test.pos = 0
    ret = StringCase.strcase(case_insensitive: true, complete: true) do
      case test
      when "te"
        1
      when "test"
        2
      when "testxxxx"
        3
      else
        4
      end
    end
    ret.should eq(2)
  end
end

describe TLpsrc2spec::TLPDB do
  it "parses sample" do
    database = File.open(fixture("texlive.tlpdb"), "r") do |fp|
      TLPDB.parse(fp)
    end
    database.should_not be_nil
  end

  it "can find a package 'test'" do
    db = File.open(fixture("texlive.tlpdb"), "r") do |fp|
      TLPDB.parse(fp)
    end
    test = db["test"]
    test.name.should eq("test")
    test.category.should eq(TLpsrc2spec::TLPDB::Category::TLCore)
    test.depends.should eq(%w[a b c d])
    date = test.catalogue_date
    date.should_not be_nil
    if date
      date.year.should eq 2019
      date.month.should eq 1
      date.day.should eq 1
      date.hour.should eq 1
      date.minute.should eq 0
      date.second.should eq 0
      date.zone.should eq Time::Location::Zone.new(nil, 3600, false)
    end
    test.catalogue_licenses.should eq(TEST_LICENSES)
    files = test.binfiles
    files.size.should eq 1
    set = files[0]
    set.size.should eq(1)
    set.arch.should eq("x86_64-linux")
    set.any? { |x| x.path == "bin/tex" }.should be_true
    posta = test.postactions
    posta.size.should eq 1
    post = posta[0]
    post.class.should eq TLpsrc2spec::TLPDB::PostAction::Script
    scr = post.as(TLpsrc2spec::TLPDB::PostAction::Script)
    scr.file.should eq "test.rb --with=\"quote\""
  end

  it "can find package the name starts with 'test'" do
    db = File.open(fixture("texlive.tlpdb"), "r") do |fp|
      TLPDB.parse(fp)
    end
    test = db[name: {TLPDB::ValueQuery::StartsWith, "test"}]
    test.map(&.name).should eq(%w[test test2])
    test.map(&.category).should eq([TLpsrc2spec::TLPDB::Category::TLCore,
                                    TLpsrc2spec::TLPDB::Category::TLCore])
    test.map(&.revision).should eq([1000, 100])
    test.map(&.longdesc).should eq([nil, <<-LONGDESC])
foo blah blah
bar
baz

LONGDESC
    test.map(&.catalogue_licenses).should eq([TEST_LICENSES, TEST2_LICENSES])
  end

  it "can find a package which contains 'bar.sty'" do
    db = File.open(fixture("texlive.tlpdb"), "r") do |fp|
      TLPDB.parse(fp)
    end
    test = db[runfiles: "bar.sty"]
    test.size.should eq(1)
    pkg = test[0]
    pkg.name.should eq("bar")
  end

  it "can find packages which their revision is less or equal to 100" do
    db = File.open(fixture("texlive.tlpdb"), "r") do |fp|
      TLPDB.parse(fp)
    end
    test = db[revision: {TLPDB::ValueQuery::LE, 100}]
    test.size.should eq(2)
    pkg = test[0]
    pkg.revision.should eq(100)
    pkg = test[1]
    pkg.revision.should eq(0)
  end
end

describe TLpsrc2spec::DirectoryTree do
  it "can build a tree" do
    root = DirectoryNode.new("/")
    root.add_entry FileNode.new("foo", root)
    root.add_entry(d = DirectoryNode.new("bar", root))
    d.add_entry FileNode.new("baz", d)
    d.add_entry FileNode.new("moe", d)
    d.add_entry(d = DirectoryNode.new("directory", d))
    tree = DirectoryTree.new(root)

    d.path.should eq("/bar/directory")
  end

  it "can insert by a tree" do
    tree = DirectoryTree.new
    tree.insert("/foo/bar/baz")
    tree.insert("/foo/bar/mey")
    tree.insert("/xffefe")
    tree.insert("/mixete")

    tree["/foo/baz"]?.should be_nil
    tree["/foo/bar/baz"].class.should eq(FileNode)
    tree["/foo/bar/"].class.should eq(DirectoryNode)
  end
end

describe TLpsrc2spec::TriggerScript do
  it "can generate from body" do
    script = TLpsrc2spec::TriggerScript.new("script body",
      trigger_by: [] of TLpsrc2spec::Dependency)
  end
end

describe TLpsrc2spec::Application do
  it "can generate proper spec" do
    File.tempfile("test", ".spec") do |tmpfile|
      app = TLpsrc2spec::Application.create(fixture("texlive.tlpdb"),
        fixture("template.spec"),
        [fixture("installed.spec")])
      app.main(tmpfile, TLpsrc2spec::TestRule)

      tmpfile.flush
      {% if flag?("show_generated_spec") %}
        tmpfile.pos = 0
        IO.copy(tmpfile, STDOUT)
      {% end %}
      specdata = RPM::Spec.open(tmpfile.path)

      pkgs = specdata.packages
      pkg_map = Hash(String, RPM::Package).new
      pkgs.each do |pkg|
        pkg_map[pkg.name] = pkg
      end
      pkg_map.has_key?("master").should be_true
      pkg_map.has_key?("texlive-test").should be_true
      pkg_map.has_key?("master-test").should be_true
      master = pkg_map["master"]
      tltest = pkg_map["texlive-test"]
      mstest = pkg_map["master-test"]

      #
      master[RPM::Tag::Summary].should eq("Master Package")
      master[RPM::Tag::Description].should eq("This is a description of the master package.\nTesting %{test}")
      master[RPM::Tag::PostTrans].should eq("/sbin/ldconfig")

      # For Just reading a specfile, TRIGGERSCRIPTS is not set, and it is
      # unable to obtain.
      # See RPM's source build/parseScript.c, l.291 (rpm-4.8.1    [4f8294aa9])
      #                                       l.400 (rpm-4.14.2.1 [4a9440006])
      mstest[RPM::Tag::TriggerName].should eq(["master"])
      mstest[RPM::Tag::TriggerIndex].should eq([0])
      mstest[RPM::Tag::TriggerFlags].should eq([RPM::Sense::TRIGGERIN.value])
    end
  end
end
