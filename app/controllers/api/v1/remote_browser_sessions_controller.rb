module Api
  module V1
    class RemoteBrowserSessionsController < BaseController
      before_action :require_session!
      limit_rate to: 10, within: 1.hour, only: :create

      def create
        purpose = params.require(:purpose)
        if !RemoteBrowserSession::PURPOSES.key?(purpose)
          render_error(:inclusion, field: :purpose, status: :unprocessable_content)
        elsif !ActiveModel::Type::Boolean.new.cast(params[:disclosure_accepted])
          render_error(:accepted, field: :disclosure_accepted, status: :unprocessable_content)
        elsif !RemoteBrowser.available?(purpose)
          render_error(:unavailable, status: :service_unavailable)
        else
          existing = current_user.remote_browser_sessions.active.exists?
          session = RemoteBrowserSession.start!(current_user, purpose, viewport: params[:viewport]&.permit(:width, :height))
          AuditEvent.record!(:remote_browser_started, request:, user: current_user, session: session.uuid, purpose:) unless existing
          render json: { session: serialize(session) }, status: existing ? :ok : :created
        end
      end

      def show
        render json: { session: serialize(browser_session) }
      end

      def destroy
        browser_session.finish!(interruption: "aborted")
        render json: { session: serialize(browser_session.reload) }
      end

      def viewer
        return render_error(:not_live, status: :conflict) unless browser_session.status == "live"

        token = browser_session.issue_viewer_token!
        url = "#{view_root}/#{browser_session.viewer_path}"
        render json: { url: "#{url}#{url.include?("?") ? "&" : "?"}token=#{token}",
                       expires_at: browser_session.viewer_token_expires_at }
      end

      def view
        session = browser_session
        if params[:token]
          return render_error(:invalid_token, status: :forbidden) unless session.consume_viewer_token!(params[:token])

          cookies.encrypted[view_cookie] = { value: { "session" => session.uuid, "user" => current_user.id },
            expires: session.expires_at, path: view_root, httponly: true, same_site: :strict, secure: request.ssl? }
        else
          grant = cookies.encrypted[view_cookie]
          valid = grant == { "session" => session.uuid, "user" => current_user.id } && session.seconds_left&.positive?
          return render_error(:invalid_token, status: :forbidden) unless valid
        end

        path = params[:path].to_s
        return tunnel(session) if path == CAST_PATH && request.headers["Upgrade"].to_s.casecmp?("websocket")
        return render_error(:not_found, status: :not_found) unless viewer_path?(session, path)

        # The client's query never reaches Steel; only the viewer page gets the query Steel itself issued.
        viewer, query = session.viewer_path.to_s.split("?", 2)
        status, content_type, body = RemoteBrowser.steel.view(session.steel_session_id, path,
          path == viewer ? query.to_s : "")
        body = body.gsub(RemoteBrowser.steel.ws_root, "#{request.ssl? ? "wss" : "ws"}://#{request.host_with_port}#{view_root}/") if path == viewer
        response.headers["Cache-Control"] = "no-store"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Content-Security-Policy"] = "frame-ancestors 'self'"
        render body:, status:, content_type:
      end

      private

      CAST_PATH = "v1/sessions/cast".freeze
      CAST_QUERY = %w[pageId pageIndex tabInfo].freeze

      # Steel's viewer streams the browser over a websocket on its private address, so after the cookie check
      # the upgrade is piped byte for byte to Steel.
      def tunnel(session)
        hijack = request.env["rack.hijack"]
        return head(:not_implemented) unless hijack

        upstream = RemoteBrowser.steel.open_socket
        query = request.query_parameters.slice(*CAST_QUERY).to_query
        SteelTunnel.open(hijack.call, upstream, path: "/#{CAST_PATH}#{"?#{query}" if query.present?}",
          host: URI(RemoteBrowser.steel.ws_root).then { "#{it.host}:#{it.port}" }, headers: SteelTunnel::FORWARDED.index_with { request.headers[it] },
          ttl: session.seconds_left.to_i)
        head :ok
      rescue RemoteBrowser::BrowserFailed
        head :bad_gateway
      end

      def browser_session = @browser_session ||= current_user.remote_browser_sessions.find_by!(uuid: params[:id])

      # Steel's API has no auth of its own, so only the viewer page and its assets may pass, never other API
      # paths. The asset prefixes are unknown until the viewer runs against real Steel.
      VIEWER_ASSET_PREFIXES = [].freeze

      def viewer_path?(session, path)
        return false if path.split("/").intersect?(%w[. ..])

        path == session.viewer_path.to_s.split("?").first || VIEWER_ASSET_PREFIXES.any? { path.start_with?(it) }
      end

      def view_root = "/api/v1/remote_browser_sessions/#{browser_session.uuid}/view"

      def view_cookie = "rb_view_#{browser_session.uuid}"

      def serialize(session)
        {
          id: session.uuid,
          purpose: session.purpose,
          status: session.status,
          queue_position: session.queue_position,
          expires_at: session.expires_at,
          seconds_left: session.seconds_left,
          login_window_seconds: RemoteBrowserSession::LOGIN_TIME.to_i,
          steps: session.steps,
          result: session.result,
          interruption: session.interruption,
          created_at: session.created_at,
          finished_at: session.finished_at
        }
      end
    end
  end
end
