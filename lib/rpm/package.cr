
require "rpm/librpm"

module RPM
  class ChangeLog
    property time : Time
    property name : String
    property text : String

    def initialize(@time, @name, @text)
    end
  end

  class Package
    def self.create(name : String, version : Version)
      hdr = LibRPM.headerNew
      if LibRPM.headerPutString(hdr, Tag::Name, name) != 1
        raise "Can't set package name: #{name}"
      end
      if LibRPM.headerPutString(hdr, Tag::Version, version.v) != 1
        raise "Can't set package version: #{version.v}"
      end
      if version.e
        if LibRPM.headerPutString(hdr, Tag::Epoch, version.e) != 1
          raise "Can't set package epoch: #{version.e}"
        end
      end
      Package.new(hdr)
    end
  end
end
