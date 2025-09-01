class ApplicationController < ActionController::API
  include ActionController::Cookies
  
  private

  def current_session_id
    @current_session_id ||= cookies[:cart_session_id] || generate_and_set_session_id
  end

  def generate_and_set_session_id
    session_id = SecureRandom.hex(16)
    response.set_cookie(:cart_session_id, {
      value: session_id,
      httponly: true,
      path: '/'
    })
    session_id
  end

  def set_session_id_header
    current_session_id
  end
end
