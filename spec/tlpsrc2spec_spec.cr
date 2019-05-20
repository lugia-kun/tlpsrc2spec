require "./spec_helper"
require "./test"

TLPDB_DATA = <<-EOF
name test
category coll
depend a b
depend c
depend d
revision 1000
catalogue-date 2019-01-01 01:00:00 +01:00
binfiles size=1 arch=x86_64-linux
 bin/tex

name test2
category coll
longdesc foo blah blah
longdesc bar
longdesc baz
shortdesc desc
revision 100
runfiles 
 texmf/tex/latex/test/test.sty

name bar
category package
revision 0
catalogue-date 2019-01-01 01:00:00 +02:00
runfiles 
 texmf/tex/latex/bar/bar.sty
docfiles 
 texmf/doc/latex/bar/bar.pdf details="Documentation" language=en

EOF

include TLpsrc2spec

describe TLpsrc2spec::TLPDB do
  io = IO::Memory.new(TLPDB_DATA)
  database = nil

  it "parses sample" do
    database = TLPDB.parse(io)
    database.should_not be_nil
  end

  it "can find a package 'test'" do
    db = database.as(TLPDB)
    test = db["test"]
    test.name.should eq("test")
    test.category.should eq("coll")
    test.depend.should eq(%w[a b c d])
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
    files.should_not be_nil
    if files
      files.size.should eq(1)
      files.arch.should eq("x86_64-linux")
      files.any? { |x| x.path == "bin/tex" }.should be_true
    end
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
  it "can build a spec" do
    app = TLpsrc2spec::Application.create(fixture("texlive.tlpdb"),
                                          fixture("template.spec"),
                                          fixture("installed.spec"))
    app.main(TLpsrc2spec::TestRule)
  end
end
