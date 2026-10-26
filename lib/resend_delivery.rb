require "net/http"

class ResendDelivery
  ENDPOINT = URI("https://api.resend.com/emails")

  def initialize(settings)
    @api_key = settings.fetch(:api_key)
  end

  def deliver!(mail)
    body = {
      from: mail[:from].to_s,
      to: mail.to,
      reply_to: mail.reply_to,
      subject: mail.subject,
      html: part(mail, "text/html"),
      text: part(mail, "text/plain")
    }.compact
    res = Net::HTTP.post(ENDPOINT, body.to_json, "Authorization" => "Bearer #{@api_key}", "Content-Type" => "application/json")
    raise "Resend #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)
  end

  private

  def part(mail, type)
    return mail.body.decoded if !mail.multipart? && mail.mime_type == type

    mail.all_parts.find { it.mime_type == type }&.decoded
  end
end
