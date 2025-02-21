@accessibility
Feature: Contrast level AA is enabled - Household Coverage Selection Page

 Background: Individual market setup
    Given the contrast level aa feature is enabled
    And EnrollRegistry contact_method_via_dropdown feature is enabled
    And the FAA feature configuration is enabled
    Given EnrollRegistry extended_aptc_individual_agreement_message feature is enabled
    Given an Individual has not signed up as an HBX user
    Given the user visits the Consumer portal during open enrollment
    When the user creates a Consumer role account
    And the user sees Your Information page
    And the user registers as an individual
    And the individual clicks on the Continue button of the Account Setup page
    And the individual sees form to enter personal information
    And the individual clicks on the Continue button of the Account Setup page
    And the individual agrees to the privacy agreeement
    And the individual answers the questions of the Identity Verification page and clicks on submit
    And the individual clicks on the Continue button of the Household Info page
    When taxhousehold info is prepared for aptc user with selected eligibility
    And has valid csr 73 benefit package without silver plans
    And the individual does not apply for assistance and clicks continue
    And the individual clicks on the Continue button of the Household Info page

  Scenario: Contrast Validation of Household Coverage Page
    Given EnrollRegistry temporary_configuration_enable_multi_tax_household_feature feature is enabled
    Then multi tax household info is prepared for aptc user with selected eligibility
    And the individual continues to the Choose Coverage page
    Then the page passes minimum level aa contrast guidelines
