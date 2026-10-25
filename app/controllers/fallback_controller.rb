class FallbackController < ActionController::API
  def index
    index = Rails.public_path.join("index.html")
    return head :not_found unless index.exist?

    response.headers["Cache-Control"] = "no-cache"
    send_file index, type: "text/html", disposition: "inline"
  end
end
