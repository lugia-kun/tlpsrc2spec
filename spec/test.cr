require "../src/rule.cr"

module TLpsrc2spec
  class TestRule < Rule
    def collect : Void
      add_package(master = Package.new("master"))
      add_package(sub1 = Package.new("texlive-test"))
      add_package(sub2 = Package.new("master-test"))

      master.summary = "Master Package"
      master.release = "1%{?dist}"
      master.version = "2019"
      master.license = ["LPPL", "GPLv2"]
      master.description = <<-EOD
      This is a description of the master package.
      Testing %%{test}
      EOD
      master.posttrans << Script.new(<<-EOD)
      /sbin/ldconfig
      EOD
      master.post << Script.new(<<-EOD, interpreter: "/usr/bin/ruby")
      puts "Hello, World!"
      EOD
      master.files << FileEntry.new("/test1")
      master.files << FileEntry.new("/test2", attr: FileAttribute.new)
      master.archdep = true

      sub1.summary = "Sub1 package"
      sub1.license = ["WTFPL"]
      sub1.description = <<-EOD
      This is a description of sub1 package.
      EOD
      sub1.postun << Script.new(<<-EOD)
      mktexlsr
      EOD
      sub1.requires << "emproxical-name"
      sub1.requires << "ender"
      sub1.provides << "foobar"

      sub2.summary = "Sub2 package"
      sub2.group = "Example Group"
      sub2.description = <<-EOD
      This is a description of sub2 package.
      EOD
      sub2.requires << RPM::Require.new("master", RPM::Version.new("1"),
        RPM::Sense::GREATER, nil)
      sub2.triggerin << TriggerScript.new("puts \"triggerred\"",
        interpreter: "/usr/bin/ruby",
        trigger_by: ["master"] of Dependency)
    end

    def master_package : Package
      packages("master")
    end
  end
end
