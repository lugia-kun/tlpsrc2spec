require "./spec_helper"
require "./test"

include TLpsrc2spec

describe TLpsrc2spec::TLPDB do
  database = nil

  it "parses sample" do
    database = File.open(fixture("texlive.tlpdb"), "r") do |fp|
      TLPDB.parse(fp)
    end
    database.should_not be_nil
  end

  it "can find a package 'test'" do
    db = database.as(TLPDB)
    test = db["test"]
    test.name.should eq("test")
    test.category.should eq("coll")
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
    db = database.as(TLPDB)
    test = db[name: {TLPDB::ValueQuery::StartsWith, "test"}]
    test.map(&.name).should eq(%w[test test2])
    test.map(&.category).should eq(%w[coll coll])
    test.map(&.revision).should eq([1000, 100])
    test.map(&.longdesc).should eq([nil, <<-LONGDESC])
foo blah blah
bar
baz

LONGDESC
  end

  it "can find a package which contains 'bar.sty'" do
    db = database.as(TLPDB)
    test = db[runfiles: "bar.sty"]
    test.size.should eq(1)
    pkg = test[0]
    pkg.name.should eq("bar")
  end

  it "can find packages which their revision is less or equal to 100" do
    db = database.as(TLPDB)
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

describe TLpsrc2spec::Application do
  File.tempfile("test", ".spec") do |tmpfile|
    it "can build a spec" do
      app = TLpsrc2spec::Application.create(fixture("texlive.tlpdb"),
        fixture("template.spec"),
        fixture("installed.spec"))
      app.main(tmpfile, TLpsrc2spec::TestRule)
    end
    tmpfile.flush
    {% if flag?("show_generated_spec") %}
      tmpfile.pos = 0
      IO.copy(tmpfile, STDOUT)
    {% end %}
    specdata = RPM::Spec.open(tmpfile.path)

    it "can generate proper spec" do
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
      master[RPM::Tag::Description].should eq("This is a description of the master package.\nTesting escapes: %{test}")
      master[RPM::Tag::PostTrans].should eq("/sbin/ldconfig")
    end
  end
end
