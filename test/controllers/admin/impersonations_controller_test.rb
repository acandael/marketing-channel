require "test_helper"

class Admin::ImpersonationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @claimed_practitioner = practitioners(:claimed)
    @unclaimed_practitioner = practitioners(:unclaimed)
  end

  test "admin can start impersonating a claimed practitioner" do
    sign_in_as(@admin)

    post impersonate_admin_practitioner_path(@claimed_practitioner)

    assert_redirected_to practitioner_root_path
    Current.session.reload
    assert_equal @claimed_practitioner.user_id, Current.session.impersonated_user_id
  end

  test "admin cannot impersonate an unclaimed practitioner" do
    sign_in_as(@admin)

    post impersonate_admin_practitioner_path(@unclaimed_practitioner)

    assert_redirected_to edit_admin_practitioner_path(@unclaimed_practitioner)
    assert_nil Current.session.reload.impersonated_user_id
  end

  test "admin can stop impersonating" do
    sign_in_as(@admin)
    Current.session.update!(impersonated_user_id: @claimed_practitioner.user_id)

    delete admin_impersonation_path

    assert_redirected_to edit_admin_practitioner_path(@claimed_practitioner)
    assert_nil Current.session.reload.impersonated_user_id
  end

  test "non-admin cannot start impersonation" do
    sign_in_as(users(:one))

    post impersonate_admin_practitioner_path(@claimed_practitioner)

    assert_redirected_to root_path
    assert_nil Current.session.reload.impersonated_user_id
  end

  test "anonymous cannot start impersonation" do
    post impersonate_admin_practitioner_path(@claimed_practitioner)

    assert_redirected_to new_session_path
  end
end
