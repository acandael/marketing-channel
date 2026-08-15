require "test_helper"

class Practitioner::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @practitioner = practitioners(:claimed)
    @practitioner_user = @practitioner.user
  end

  test "impersonator cannot change practitioner password" do
    sign_in_as(@admin)
    Current.session.update!(impersonated_user_id: @practitioner_user.id)

    original_digest = @practitioner_user.password_digest

    patch practitioner_settings_path, params: {
      section: "password",
      current_password: "password",
      new_password: "newpassword123",
      new_password_confirmation: "newpassword123"
    }

    assert_redirected_to practitioner_settings_path
    assert_equal original_digest, @practitioner_user.reload.password_digest
  end

  test "impersonator cannot change practitioner email" do
    sign_in_as(@admin)
    Current.session.update!(impersonated_user_id: @practitioner_user.id)

    patch practitioner_settings_path, params: {
      section: "email",
      new_email_address: "new@example.com"
    }

    assert_redirected_to practitioner_settings_path
    assert_nil @practitioner_user.reload.pending_email_address
  end
end
