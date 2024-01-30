# frozen_string_literal: true

RSpec.shared_examples 'restrictions on verification document upload' do
  it "does not allow certain file types to be uploaded" do
    file = fixture_file_upload(upload_file_path)
    allow(Aws::S3Storage).to receive(:save).and_return(doc_uri)
    params = { person: { consumer_role: person.consumer_role }, file: [file] }
    post :upload, params: params

    expect(flash[:error]).to include(I18n.t("insured.verification_doc_file_error"))
    expect(response).to have_http_status(:redirect)
  end
end