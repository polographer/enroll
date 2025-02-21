require 'rails_helper'

describe FamilyMember, dbclean: :after_each do
  subject { FamilyMember.new(:is_primary_applicant => nil, :is_coverage_applicant => nil) }

  before(:each) do
    subject.valid?
  end

  it "should validate the presence of a person" do
    expect(subject).to have_errors_on(:person_id)
  end
  it "should validate the presence of is_primary_applicant" do
    expect(subject).to have_errors_on(:is_primary_applicant)
  end
  it "should validate the presence of is_coverage_applicant" do
    expect(subject).to have_errors_on(:is_coverage_applicant)
  end

end

describe FamilyMember, "given a person", dbclean: :after_each do
  let(:person) { Person.new }
  subject { FamilyMember.new(:person => person) }

  it "delegates #ivl_coverage_selected to person" do
    expect(person).to receive(:ivl_coverage_selected)
    subject.ivl_coverage_selected
  end

  it { should delegate_method(:age_off_excluded).to(:person) }
end


describe FamilyMember, "given a person", dbclean: :after_each do
  let(:person) { create :person ,:with_family }

  it "should error when trying to save duplicate family member" do
    family_member = FamilyMember.new(:person => person)
    person.families.first.family_members << family_member
    person.families.first.family_members << family_member
    expect(family_member.errors.full_messages.join(",")).to match(/Family members Duplicate family_members for person/)
  end
end

describe FamilyMember, dbclean: :after_each do
  context "a family with members exists" do
    include_context "BradyBunchAfterAll"

    before :each do
      create_brady_families
    end

    let(:family_member_id) {mikes_family.primary_applicant.id}

    it "FamilyMember.find(id) should work" do
      expect(FamilyMember.find(family_member_id).id.to_s).to eq family_member_id.to_s
    end

    it "should be possible to find the primary_relationship" do
      mikes_family.dependents.each do |dependent|
        if brady_children.include?(dependent.person)
          expect(dependent.primary_relationship).to eq "child"
        else
          expect(dependent.primary_relationship).to eq "spouse"
        end
      end
    end
  end

  let(:p0) {Person.create!(first_name: "Dan", last_name: "Aurbach")}
  let(:p1) {Person.create!(first_name: "Patrick", last_name: "Carney")}
  let(:ag) do
    fam = Family.new
    fam.family_members.build(
      :person => p0,
      :is_primary_applicant => true
    )
    fam.save!
    fam
  end
  let(:family_member_params) {
    { person: p1,
      is_primary_applicant: true,
      is_coverage_applicant: true,
      is_consent_applicant: true,
      is_active: true}
  }

  context "parent" do
    it "should equal to family" do
      family_member = ag.family_members.create(**family_member_params)
      expect(family_member.parent).to eq ag
    end

    it "should raise error with nil family" do
      family_member = FamilyMember.new(**family_member_params)
      expect{family_member.parent}.to raise_error(RuntimeError, "undefined parent family")
    end
  end

  context "person" do
    it "with person" do
      family_member = FamilyMember.new(**family_member_params)
      family_member.person= p1
      expect(family_member.person).to eq p1
    end

    it "without person" do
      expect(FamilyMember.new(**family_member_params.except(:person)).valid?).to be_falsey
    end
  end

  context "broker" do
    let(:broker_role)   {FactoryBot.create(:broker_role)}
    let(:broker_role2)  {FactoryBot.create(:broker_role)}

    it "with broker_role" do
      family_member = ag.family_members.create(**family_member_params)
      family_member.broker= broker_role
      expect(family_member.broker).to eq broker_role
    end

    it "without broker_role" do
      family_member = ag.family_members.create(**family_member_params)
      family_member.broker = broker_role
      expect(family_member.broker).to eq broker_role

      family_member.broker = broker_role2
      expect(family_member.broker).to eq broker_role2
    end
  end

  context "comments" do
    it "with blank" do
      family_member = ag.family_members.create({
        person: p0,
        is_primary_applicant: true,
        is_coverage_applicant: true,
        is_consent_applicant: true,
        is_active: true,
        comments: [{priority: 'normal', content: ""}]
      })

      expect(family_member.errors[:comments].any?).to eq true
    end

    it "without blank" do
      family_member = ag.family_members.create({
        person: p0,
        is_primary_applicant: true,
        is_coverage_applicant: true,
        is_consent_applicant: true,
        is_active: true,
        comments: [{priority: 'normal', content: "aaas"}]
      })

      expect(family_member.errors[:comments].any?).to eq false
      expect(family_member.comments.size).to eq 1
    end
  end

  describe "instantiates object." do
    it "sets and gets all basic model fields and embeds in parent class" do
      a = FamilyMember.new(
        person: p0,
        is_primary_applicant: true,
        is_coverage_applicant: true,
        is_consent_applicant: true,
        is_active: true
        )

      a.family = ag

      expect(a.person.last_name).to eql(p0.last_name)
      expect(a.person_id).to eql(p0._id)

      expect(a.is_primary_applicant?).to eql(true)
      expect(a.is_coverage_applicant?).to eql(true)
      expect(a.is_consent_applicant?).to eql(true)
    end
  end
end

describe FamilyMember, "which is inactive", dbclean: :after_each do
  # TODO: Note 7/17/2019 this wasn't even a finished block, xit'd out
  xit "can be reactivated with a specified relationship" do

  end
end

describe FamilyMember, "given a relationship to update", dbclean: :after_each do
  let(:family) { FactoryBot.create(:family, :with_primary_family_member)}
  let(:relationship) { "spouse" }
  let(:person) { FactoryBot.build(:person) }
  subject { FactoryBot.build(:family_member, person: person, family: family) }

  it "should do nothing if the relationship is the same" do
    subject.update_relationship(subject.primary_relationship)
  end

  it "should update the relationship if different" do
    expect(subject.primary_relationship).not_to eq relationship
    subject.update_relationship(relationship)
    expect(subject.primary_relationship).to eq relationship
  end
end

describe FamilyMember, 'call back deactivate_tax_households on update', dbclean: :after_each do
  let!(:person) {FactoryBot.create(:person)}
  let!(:family) {FactoryBot.create(:family, :with_primary_family_member, person: person)}
  let!(:household) {FactoryBot.create(:household, family: family)}
  let!(:tax_household) {FactoryBot.create(:tax_household, household: household, effective_ending_on: nil, is_eligibility_determined: true)}
  let!(:eligibility_determination) {FactoryBot.create(:eligibility_determination, tax_household: tax_household, csr_percent_as_integer: 10)}

  it 'should deactivate eligibility when member is updated' do
    family.active_household.tax_households << tax_household
    family.save!
    family.primary_applicant.update_attributes!(is_active: false)
    family.reload
    expect(family.active_household.tax_households.first.effective_ending_on).not_to eq nil
  end
end

describe '#deactivate_tax_households' do
  let(:person) { FactoryBot.create(:person) }
  let(:family) { FactoryBot.create(:family, :with_primary_family_member, person: person) }
  let(:primary_family_member) { family.primary_applicant }

  context 'when Multi Tax Households feature is enabled' do
    let(:tax_household_group) { FactoryBot.create(:tax_household_group, family: family) }

    before do
      allow(EnrollRegistry[:temporary_configuration_enable_multi_tax_household_feature].feature).to receive(:is_enabled).and_return(true)
    end

    context 'family member is deleted' do
      it 'deactivates active tax household group' do
        expect(tax_household_group.end_on).to be_nil
        primary_family_member.update_attributes!(is_active: false)
        expect(tax_household_group.reload.end_on).not_to be_nil
      end
    end

    context 'family member is updated' do
      it 'does not deactivate active tax household group' do
        expect(tax_household_group.end_on).to be_nil
        primary_family_member.update_attributes!(external_member_id: '100992')
        expect(tax_household_group.reload.end_on).to be_nil
      end
    end
  end
end

describe FamilyMember, 'callback set crm_notifiction_needed', dbclean: :after_each do
  let!(:person) {FactoryBot.create(:person)}
  let!(:family) {FactoryBot.create(:family, :with_primary_family_member, person: person)}
  let!(:dependent_person) { FactoryBot.create(:person, :with_consumer_role) }
  let(:dependent_family_member) do
    FamilyMember.new(is_primary_applicant: false, is_consent_applicant: false, person: dependent_person)
  end

  before do
    allow(EnrollRegistry).to receive(:feature_enabled?).and_return(false)
    # have to run save an extra time due to the encrytped ssn
    person.is_incarcerated = true
    person.save!
    person.set(crm_notifiction_needed: false)
    dependent_person.is_incarcerated = true
    dependent_person.save!
    dependent_person.set(crm_notifiction_needed: false)
    family.set(crm_notifiction_needed: false)
    allow(EnrollRegistry).to receive(:feature_enabled?).with(:check_for_crm_updates).and_return(true)
    family.family_members << dependent_family_member
    person.person_relationships << PersonRelationship.new(relative: person, kind: "self")
    person.person_relationships.build(relative: dependent_person, kind: "spouse")
    person.save!
  end

  it 'should set to true on create' do
    family.reload
    expect(family.crm_notifiction_needed).to eq true
  end

  it 'should set to true on destroy' do
    family.set(crm_notifiction_needed: false)
    dependent_family_member.destroy
    family.reload
    expect(family.crm_notifiction_needed).to eq true
  end
end

# TODO: Renable the spec on the after hook is enabled on family_member model
# describe FamilyMember, 'call back deactivate_tax_households on create', dbclean: :after_each do
#   let!(:person) {FactoryBot.create(:person)}
#   let!(:spouse)  { FactoryBot.create(:person)}
#   let!(:family) {FactoryBot.create(:family, :with_primary_family_member, person: person)}
#   let!(:household) {FactoryBot.create(:household, family: family)}
#   let!(:tax_household) {FactoryBot.create(:tax_household, household: household, effective_starting_on: Date.new(2020, 1, 1), effective_ending_on: nil, is_eligibility_determined: true)}
#   let!(:eligibility_determination) {FactoryBot.create(:eligibility_determination, tax_household: tax_household, csr_percent_as_integer: 10)}
#   it 'should deactivate eligibility when member is updated' do
#     family.active_household.tax_households << tax_household
#     family.save!
#     family.family_members.create(is_primary_applicant: false, person: spouse)
#     family.reload
#     expect(family.active_household.tax_households.first.effective_ending_on).not_to eq nil
#   end
# end
