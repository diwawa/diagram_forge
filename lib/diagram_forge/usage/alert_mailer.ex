defmodule DiagramForge.Usage.AlertMailer do
  @moduledoc """
  Email notifications for usage alerts.
  """

  import Swoosh.Email

  alias DiagramForge.Usage
  alias DiagramForge.Usage.Alert

  @doc """
  Builds an email for a usage alert notification.
  """
  def usage_alert(admin_email, %Alert{} = alert) do
    alert = DiagramForge.Repo.preload(alert, [:threshold, :user])

    subject = build_subject(alert)
    text_body = build_text_body(alert)
    html_body = build_html_body(alert)

    new()
    |> to(admin_email)
    |> from({"DiagramForge", from_email()})
    |> subject(subject)
    |> text_body(text_body)
    |> html_body(html_body)
  end

  defp from_email do
    Application.get_env(:diagram_forge, :from_email, "noreply@diagramforge.com")
  end

  defp build_subject(%Alert{threshold: threshold} = alert) do
    scope_text =
      case threshold.scope do
        "total" -> "Total"
        "per_user" -> "User #{alert.user && alert.user.email}"
      end

    "[DiagramForge] Usage Alert: #{scope_text} exceeded #{threshold.name}"
  end

  defp build_text_body(%Alert{} = alert) do
    """
    DiagramForge Usage Alert

    A usage threshold has been exceeded:

    Threshold: #{alert.threshold.name}
    Period: #{alert.period_start} to #{alert.period_end}
    #{user_line(alert)}
    Amount: $#{Usage.format_cents(alert.amount_cents)}
    Limit: $#{Usage.format_cents(alert.threshold.threshold_cents)}

    Please review usage at: #{admin_url()}/usage

    ---
    DiagramForge
    """
  end

  defp build_html_body(%Alert{} = alert) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #f8d7da; color: #721c24; padding: 15px; border-radius: 8px; margin-bottom: 20px; }
        .header h1 { margin: 0; font-size: 18px; }
        .details { background: #f8f9fa; padding: 15px; border-radius: 8px; }
        .details table { width: 100%; }
        .details td { padding: 8px 0; }
        .details td:first-child { font-weight: 600; width: 120px; }
        .amount { color: #dc3545; font-weight: bold; }
        .button { display: inline-block; background: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; margin-top: 20px; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; font-size: 12px; color: #666; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>⚠️ Usage Alert</h1>
        </div>

        <p>A usage threshold has been exceeded on DiagramForge:</p>

        <div class="details">
          <table>
            <tr>
              <td>Threshold</td>
              <td>#{alert.threshold.name}</td>
            </tr>
            <tr>
              <td>Period</td>
              <td>#{alert.period_start} to #{alert.period_end}</td>
            </tr>
            #{user_row_html(alert)}
            <tr>
              <td>Amount</td>
              <td class="amount">$#{Usage.format_cents(alert.amount_cents)}</td>
            </tr>
            <tr>
              <td>Limit</td>
              <td>$#{Usage.format_cents(alert.threshold.threshold_cents)}</td>
            </tr>
          </table>
        </div>

        <a href="#{admin_url()}/usage" class="button">Review Usage Dashboard</a>

        <div class="footer">
          <p>DiagramForge - API Usage Monitoring</p>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp user_line(%Alert{threshold: %{scope: "per_user"}, user: user}) when not is_nil(user) do
    "User: #{user.email}"
  end

  defp user_line(_), do: ""

  defp user_row_html(%Alert{threshold: %{scope: "per_user"}, user: user}) when not is_nil(user) do
    """
    <tr>
      <td>User</td>
      <td>#{user.email}</td>
    </tr>
    """
  end

  defp user_row_html(_), do: ""

  defp admin_url do
    Application.get_env(:diagram_forge, DiagramForgeWeb.Endpoint)[:url][:host] ||
      "localhost:4000"
      |> then(fn host -> "https://#{host}/admin" end)
  end
end
