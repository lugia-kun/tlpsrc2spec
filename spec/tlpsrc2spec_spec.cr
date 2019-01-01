require "./spec_helper"

require "../spec/rpm/enum_data"

include EnumCompare

enum_compare(RPM::Tag, RPM::EnumData::Tag, "RPMTAG_")

describe TLpsrc2spec do
  # TODO: Write tests

  it "works" do
    false.should eq(true)
  end
end
