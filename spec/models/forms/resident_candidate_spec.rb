# frozen_string_literal: true

require 'rails_helper'
describe Forms::ResidentCandidate, "asked to match a person", dbclean: :after_each do

  before :each do
    DatabaseCleaner.clean
  end

  let(:user){ create(:user) }
  let!(:person) { create(:person, :with_ssn, user: user) }

  let!(:params) do
    {
      :dob => "2012-10-12",
      :ssn => person.reload.ssn,
      :first_name => "yo",
      :last_name => "guy",
      :gender => "m",
      :user_id => 20,
      :is_applying_coverage => false
    }
  end

  let(:subject) { Forms::ResidentCandidate.new(params) }

  after(:each) do
    DatabaseCleaner.clean
  end

  context "uniq ssn" do

    context 'when ssn blank' do
      let(:params) { {:ssn => nil} }

      it "return true " do
        expect(subject.uniq_ssn).to eq true
      end
    end

    context 'when ssn matches with claimed user account' do
      it "should add errors" do
        subject.uniq_ssn
        expect(subject.errors[:ssn_taken]).to eq ["The social security number you entered is affiliated with another account."]
      end
    end

    context 'when ssn matches with unclaimed user account' do
      let(:person) { create(:person, :with_ssn) }

      it "should not add errors" do
        subject.uniq_ssn
        expect(subject.errors[:base]).to eq []
      end
    end
  end
end


describe "match a person in db" do
  let(:subject) do
    Forms::ResidentCandidate.new({
                                   :dob => search_params.dob,
                                   :ssn => search_params.ssn,
                                   :first_name => search_param_name.first_name,
                                   :last_name => search_param_name.last_name,
                                   :gender => "m",
                                   :user_id => 20,
                                   :is_applying_coverage => false
                                 })
  end

  let(:search_params) { double(dob: db_person.dob.strftime("%Y-%m-%d"), ssn: db_person.ssn)}
  let(:search_param_name) { double(first_name: db_person.first_name, last_name: db_person.last_name)}

  after(:each) do
    DatabaseCleaner.clean
  end

  context "with a person with a first name, last name, dob and no SSN" do
    let(:db_person) { Person.create!(first_name: "Joe", last_name: "Kramer", dob: "1993-03-30", ssn: '')}

    it 'matches the person by last_name, first name and dob if there is no ssn' do
      expect(subject.match_person).to eq db_person
    end

    it 'matches the person ingoring case' do
      subject.first_name.upcase!
      subject.last_name.downcase!
      expect(subject.match_person).to eq db_person
    end

    context "with a person who has no ssn but an employer staff role", dbclean: :after_each do
      let!(:site)                { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
      let!(:benefit_sponsor)     { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
      let!(:employer_profile)    { benefit_sponsor.employer_profile }
      let!(:employer_staff_role) { EmployerStaffRole.create(person: db_person, benefit_sponsor_employer_profile_id: employer_profile.id) }

      it 'matches person by last name, first name and dob' do
        db_person.employer_staff_roles << employer_staff_role
        db_person.save!
        allow(search_params).to receive(:ssn).and_return("517991234")
        expect(subject.match_person).to eq db_person
      end
    end
  end

  context "with a person with a first name, last name, dob and ssn" do
    let(:db_person) { Person.create!(first_name: "Jack",   last_name: "Weiner",   dob: "1943-05-14", ssn: "517994321")}

    it 'matches the person by ssn and dob' do
      expect(subject.match_person).to eq db_person
    end

    it 'does not find the person if payload has a different ssn from the person' do
      subject.ssn = "888891234"
      expect(subject.match_person).to eq nil
    end
  end

  context "with a person with a first name, different last name, dob and ssn" do
    let(:described_class) do
      Forms::ConsumerCandidate.new({
                                     :dob => "1943-05-14",
                                     :ssn => "517994321",
                                     :first_name => "test",
                                     :last_name => "one",
                                     :gender => "m",
                                     :user_id => 20,
                                     :is_applying_coverage => false
                                   })
    end
    let!(:db_person) { Person.create!(first_name: "test",   last_name: "o",   dob: "1943-05-14", ssn: "517994321")}

    it 'should be invalid' do
      allow(described_class).to receive(:state_based_policy_satisfied?).and_return(true)
      described_class.instance_variable_set(:@configuration, {ssn_present: ["first_name", "last_name", "dob", "encrypted_ssn"]})
      expect(described_class.valid?).to eq false
    end
  end
end