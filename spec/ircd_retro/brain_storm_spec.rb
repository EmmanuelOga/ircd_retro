require 'spec_helper'

describe IRCDRetro::BrainStorm do
  let(:bs) { IRCDRetro::BrainStorm.new }

  before do
    bs.start(1)
    bs << "Uno"
    bs << "Dos"
    bs << "Tres"
  end

  it "allows mergin votes" do
    bs.merge([0, 2])
    bs.items[0].should == nil
    bs.items[1].should == "Dos"
    bs.items[2].should == nil
    bs.items[3].should == "Uno / Tres"

    bs.merge([1, 3])
    bs.items[4].should == "Dos / Uno / Tres"
  end

  context "voting" do
    it "allows voting" do
      bs.vote("Tony", [0,0,2])
      bs.vote("Peter", [0,0,2])
      result = bs.result
      result[0].should == [0, 4, "Uno"]
      result[1].should == [2, 2, "Tres"]
    end

    it "knows when the voting is complete" do
      nicks = ["Tony", "Peter"]
      bs.voters = nicks.length
      bs.votation_complete?.should be_false

      bs.vote("Tony", [0,0,2])
      bs.votation_complete?.should be_false

      bs.vote("Peter", [0,0,2])
      bs.votation_complete?.should be_true
    end
  end
end

