$(function() {
  applyBrokerTabClickHandlers();
});

function applyBrokerTabClickHandlers(){
  $('div[name=broker_agency_tabs] >').children().each( function() { 
    $(this).change(function(){
      filter = 'broker';
      agency_type = $(this).attr('value');
      action_url = '/broker_agencies/broker_roles/new_broker.js';
      if (agency_type == 'new') {
        action_url = '/broker_agencies/broker_roles/new_broker_agency.js';
      }
      $.ajax({
        url: action_url,
        type: "GET",
        data : { 'filter': filter, 'agency_type': agency_type }
      });
    })
  })
}

$(document).on('click', "a.select-broker-agency", function() {
  $('.result .form-border').removeClass("agency-selected");
  $('#person_broker_agency_id').val($(this).data('broker_agency_profile_id'));
  $(this).parents(".form-border").addClass("agency-selected");
});

$(document).on('click', '.general-agency-search a.search', function() {
  $('.general-agency-search .result').empty();
  var general_agency_search = $('input#agency_search').val();
  if (general_agency_search != undefined && general_agency_search != ""){
    $(this).button('loading');
    $('#organization_general_agency_profile_id').val("");
    $.ajax({
      url: '/general_agencies/profiles/search_general_agency.js',
      type: "GET",
      data : { 'general_agency_search': general_agency_search }
    });
  };
});
$(document).on('click', "a.select-general-agency", function() {
  $('.result .form-border').removeClass("agency-selected");
  $('#organization_general_agency_profile_id').val($(this).data('general_agency_profile_id'));
  $(this).parents(".form-border").addClass("agency-selected");
});
