# frozen_string_literal: true

class Insured::VerificationDocumentsController < ApplicationController
  include ApplicationHelper

  before_action :set_current_person
  before_action :find_type, :find_docs_owner, only: [:upload]
  before_action :check_for_consumer_role

  def upload
    authorize @consumer_role, :verification_document_upload?

    @doc_errors = []
    if params[:file].blank?
      flash[:error] = "File not uploaded. Please select the file to upload."
    elsif !valid_file_uploads?(params[:file], FileUploadValidator::VERIFICATION_DOC_TYPES)
      redirect_to verification_insured_families_path
      return
    else
      params[:file].each do |file|
        doc_uri = Aws::S3Storage.save(file_path(file), 'id-verification')
        if doc_uri.present?
          if update_vlp_documents(file_name(file), doc_uri)
            add_type_history_element(file)
            flash[:notice] = "File Saved"
          else
            flash[:error] = "Could not save file. #{@doc_errors.join('. ')}"
            redirect_back(fallback_location: verification_insured_families_path)
            return
          end
        else
          flash[:error] = "Could not save file"
        end
      end
    end
    redirect_to verification_insured_families_path
  end

  def download
    authorize @consumer_role, :verification_document_download?

    document = get_document(params[:key])
    if document.present?
      bucket = env_bucket_name('id-verification')
      uri = "urn:openhbx:terms:v1:file_storage:s3:bucket:#{bucket}##{params[:key]}"
      send_data Aws::S3Storage.find(uri), download_options(document)
    else
      flash[:error] = "File does not exist or you are not authorized to access it."
      redirect_to verification_insured_families_path
    end
    vlp_docs_clean(@person)
  end

  private

  def find_type
    find_docs_owner
    @verification_type = @docs_owner.verification_types.find(params[:verification_type]) if params[:verification_type]
  end

  def check_for_consumer_role
    @consumer_role = @person.consumer_role
    return if @consumer_role

    flash[:error] = "No consumer role exists, you are not authorized to upload documents"
    redirect_to verification_insured_families_path
  end

  def file_path(file)
    file.tempfile.path
  end

  def file_name(file)
    file.original_filename
  end

  def find_docs_owner
    @docs_owner = Person.find(params[:docs_owner]) if params[:docs_owner]
  end

  def update_vlp_documents(title, file_uri)
    document = @verification_type.vlp_documents.build
    success = document.update_attributes({:identifier=>file_uri, :subject => title, :title=>title, :status=>"downloaded"})
    @verification_type.update_attributes(:rejected => false, :validation_status => "review", :update_reason => "document uploaded")
    @doc_errors = document.errors.full_messages unless success
    @docs_owner.save
  end

  def update_paper_application(title, file_uri)
    document = @docs_owner.resident_role.vlp_documents.build
    success = document.update_attributes({:identifier=>file_uri, :subject => title, :title=>title, :status=>"downloaded", :verification_type=>params[:verification_type]})
    @doc_errors = document.errors.full_messages unless success
    @docs_owner.save
  end

  def get_document(key)
    @person.consumer_role.find_vlp_document_by_key(key)
  end

  def download_options(document)
    options = {}
    options[:content_type] = document.format
    options[:filename] = document.title
    options
  end

  def add_type_history_element(file)
    actor = current_user ? current_user.email : "external source or script"
    action = "Upload #{file_name(file)}" if params[:action] == "upload"
    @verification_type.add_type_history_element(action: action, modifier: actor)
  end

  def vlp_docs_clean(person)
    existing_documents = person.consumer_role.vlp_documents
    person_consumer_role=Person.find(person.id).consumer_role
    person_consumer_role.vlp_documents =[]
    person_consumer_role.save
    person_consumer_role=Person.find(person.id).consumer_role
    person_consumer_role.vlp_documents = existing_documents.uniq
    person_consumer_role.save
  end

end
