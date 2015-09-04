require 'rails_helper'
require 'spec_helper'

describe API::V1::Advocates::DateAttended do

  include Rack::Test::Methods

  CREATE_DATE_ATTENDED_ENDPOINT = "/api/advocates/dates_attended"
  VALIDATE_DATE_ATTENDED_ENDPOINT = "/api/advocates/dates_attended/validate"

  ALL_DATES_ATTENDED_ENDPOINTS = [VALIDATE_DATE_ATTENDED_ENDPOINT, CREATE_DATE_ATTENDED_ENDPOINT]
  FORBIDDEN_DATES_ATTENDED_VERBS = [:get, :put, :patch, :delete]

  let!(:fee)                { create(:fee, id: 1) }
  let!(:valid_params)       { {attended_item_id: fee.reload.uuid, attended_item_type: 'Fee', date: '10 May 2015', date_to: '12 May 2015'} }

  context 'when sending non-permitted verbs' do
    ALL_DATES_ATTENDED_ENDPOINTS.each do |endpoint| # for each endpoint
      context "to endpoint #{endpoint}" do
        FORBIDDEN_DATES_ATTENDED_VERBS.each do |api_verb| # test that each FORBIDDEN_VERB returns 405
          it "#{api_verb.upcase} should return a status of 405" do
            response = send api_verb, endpoint, format: :json
            expect(response.status).to eq 405
          end
        end
      end
    end
  end

  describe "POST #{CREATE_DATE_ATTENDED_ENDPOINT}" do

    def post_to_create_endpoint(params)
      post CREATE_DATE_ATTENDED_ENDPOINT, params, format: :json
    end


    context 'when date_attended params are valid' do

      it "should create date_attended, return 201 and date_attended JSON output including UUID" do
        response = post_to_create_endpoint(valid_params)
        expect(response.status).to eq 201
        json = JSON.parse(response.body)
        expect(json['id']).not_to be_nil
        expect(DateAttended.find_by(uuid: json['id']).uuid).to eq(json['id'])
        expect(DateAttended.find_by(uuid: json['id']).attended_item.uuid).to eq(json['attended_item_id'])
      end

      it "should create one new date attended" do
        expect{ post_to_create_endpoint(valid_params) }.to change { DateAttended.count }.by(1)
      end

      it 'should create a new record using the params provided' do
        post_to_create_endpoint(valid_params)
        date_attended = DateAttended.last
        expect(date_attended.date).to eq '10 May 2015'
        expect(date_attended.date_to).to eq '12 May 2015'
        expect(date_attended.attended_item_id).to eq 1
      end

    end

    context 'when date_attended params are invalid' do

      context "missing expected params" do
        it "should return a JSON error array with required model attributes" do
          valid_params.delete(:date)
          response = post_to_create_endpoint(valid_params)
          expect(response.status).to eq 400
          expect(response.body).to eq "[{\"error\":\"Date can't be blank\"}]"
        end
      end

      context "grape api implicit type validation error" do
        it "should return 400 and JSON error array of error messages" do
          valid_params[:date] = '32 May 2015'
          valid_params[:date_to] = '32 May 2015'
          response = post_to_create_endpoint(valid_params)
          expect(response.status).to eq(400)
          expect(response.body).to eq "[{\"error\":\"date is invalid\"},{\"error\":\"date_to is invalid\"}]"
        end
      end

      context 'missing attended item id' do
        it 'should return 400 and a JSON error array' do
          valid_params.delete(:attended_item_id)
          response = post_to_create_endpoint(valid_params)
          expect(response.status).to eq 400
          expect(response.body).to eq "[{\"error\":\"Attended item can't be blank\"}]"
        end
      end

      context 'invalid attended item id' do
        it 'should return 400 and a JSON error array' do
          valid_params[:attended_item_id] = SecureRandom.uuid
          response = post_to_create_endpoint(valid_params)
          expect(response.status).to eq 400
          expect(response.body).to eq "[{\"error\":\"Attended item can't be blank\"}]"
        end
      end

      context "malformed attended_item_id UUID" do
        it "should be temporarily handled explicitly (until rails 4.2 upgrade)" do
          valid_params[:attended_item_id] = 'any-old-rubbish'
          response = post_to_create_endpoint(valid_params)
          expect(response.status).to eq(400)
          expect(response.body).to eq "[{\"error\":\"malformed UUID\"}]"
        end
      end

    end

  end

  describe "POST #{VALIDATE_DATE_ATTENDED_ENDPOINT}" do

    def post_to_validate_endpoint(params)
      post VALIDATE_DATE_ATTENDED_ENDPOINT, params, format: :json
    end

     it 'valid requests should return 200 and String true' do
      response = post_to_validate_endpoint(valid_params)
      expect(response.status).to eq 200
      json = JSON.parse(response.body)
      expect(json).to eq({ "valid" => true })
    end

    it 'missing required params should return 400 and a JSON error array' do
      valid_params.delete(:date)
      response = post_to_validate_endpoint(valid_params)
      expect(response.status).to eq 400
      expect(response.body).to eq "[{\"error\":\"Date can't be blank\"}]"
    end

    it 'invalid attended item id should return 400 and a JSON error array' do
      valid_params[:attended_item_id] = SecureRandom.uuid
      response = post_to_validate_endpoint(valid_params)
      expect(response.status).to eq 400
      expect(response.body).to eq "[{\"error\":\"Attended item can't be blank\"}]"
    end

  end

end

