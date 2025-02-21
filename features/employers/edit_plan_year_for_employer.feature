Feature: Edit Plan Year For Initial Employer

  Background: Setup site, employer, and benefit application
    Given the shop market configuration is enabled
    Given all announcements are enabled for user to select
    Given a CCA site exists with a benefit market
    Given benefit market catalog exists for enrollment_open initial employer with health benefits
    And there is an employer ABC Widgets
    And ABC Widgets employer has a staff role
    And staff role person logged in
    And update rating area
    And initial employer ABC Widgets has draft benefit application

  Scenario Outline: Editing contribution percentages for existing plan year 100 contribution percent
    When ABC Widgets is logged in and on the home page
    And staff role person clicked on benefits tab
    Then employer should see edit plan year button
    And employer clicked on edit plan year button
    Then employer should see form for benefit application and benefit package
    And employer updated <contribution_percent> contribution percent for the application
    And employer clicked on save plan year button
    And employer should see a success message after clicking on save plan year button
    And employer logs out

    Examples:
      | contribution_percent |
      | 100                  |
  
  Scenario Outline: Editing contribution percentages for existing plan year zero contribution percent
    When ABC Widgets is logged in and on the home page
    And staff role person clicked on benefits tab
    Then employer should see edit plan year button
    And employer clicked on edit plan year button
    Then employer should see form for benefit application and benefit package
    And employer updated <contribution_percent> contribution percent for the application
    And employer should see create plan year button disabled if plan year start is not the first of the year
    And employer logs out

    Examples:
      | contribution_percent |
      | 0                    |

  Scenario: Employer should be able to change open enrollment end dates
    When ABC Widgets is logged in and on the home page
    And staff role person clicked on benefits tab
    Then employer should see edit plan year button
    And employer clicked on edit plan year button
    And employer clicked on edit plan year button
    Then employer updates open enrollment end date to 5
    And employer clicks on update plan year
    And employer clicked on edit plan year button
    Then employer updates open enrollment end date to 8
    And employer clicks on update plan year
    And employer should see a success message
    And employer logs out