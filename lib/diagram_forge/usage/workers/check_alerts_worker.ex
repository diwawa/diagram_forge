defmodule DiagramForge.Usage.Workers.CheckAlertsWorker do
  @moduledoc """
  Oban worker that checks usage thresholds and creates alerts.

  This job:
  1. Checks all active alert thresholds
  2. Creates alerts for any thresholds that are exceeded
  3. Sends email notifications for new alerts

  Runs hourly via Oban cron.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  alias DiagramForge.Mailer
  alias DiagramForge.Usage
  alias DiagramForge.Usage.AlertMailer

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Starting usage alert check")

    # Check all thresholds and create alerts
    new_alerts = Usage.check_all_thresholds()

    Logger.info("Created #{length(new_alerts)} new alerts")

    # Send email notifications for alerts that need them
    send_alert_emails()

    :ok
  end

  defp send_alert_emails do
    alerts = Usage.list_alerts_needing_email()

    Enum.each(alerts, fn alert ->
      case send_alert_email(alert) do
        :ok ->
          Usage.mark_alert_email_sent(alert)
          Logger.info("Sent alert email for alert_id=#{alert.id}")

        {:error, reason} ->
          Logger.error("Failed to send alert email for alert_id=#{alert.id}: #{inspect(reason)}")
      end
    end)
  end

  defp send_alert_email(alert) do
    # Get admin email from config or use first admin user
    admin_email = get_admin_email()

    if admin_email do
      AlertMailer.usage_alert(admin_email, alert)
      |> Mailer.deliver()

      :ok
    else
      Logger.warning("No admin email configured for usage alerts")
      {:error, :no_admin_email}
    end
  end

  defp get_admin_email do
    Application.get_env(:diagram_forge, :admin_email)
  end
end
