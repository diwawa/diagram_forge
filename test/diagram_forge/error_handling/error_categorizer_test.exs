defmodule DiagramForge.ErrorHandling.ErrorCategorizerTest do
  use ExUnit.Case, async: true

  alias DiagramForge.ErrorHandling.ErrorCategorizer

  describe "categorize_error/1" do
    test "categorizes 429 as rate_limit with high severity" do
      assert {:rate_limit, :high} = ErrorCategorizer.categorize_error({:error, %{status: 429}})
    end

    test "categorizes 401 as authentication with critical severity" do
      assert {:authentication, :critical} =
               ErrorCategorizer.categorize_error({:error, %{status: 401}})
    end

    test "categorizes 403 as authentication with critical severity" do
      assert {:authentication, :critical} =
               ErrorCategorizer.categorize_error({:error, %{status: 403}})
    end

    test "categorizes 503 as transient with medium severity" do
      assert {:transient, :medium} = ErrorCategorizer.categorize_error({:error, %{status: 503}})
    end

    test "categorizes 504 as transient with medium severity" do
      assert {:transient, :medium} = ErrorCategorizer.categorize_error({:error, %{status: 504}})
    end

    test "categorizes 502 as transient with medium severity" do
      assert {:transient, :medium} = ErrorCategorizer.categorize_error({:error, %{status: 502}})
    end

    test "categorizes 400 as permanent with medium severity" do
      assert {:permanent, :medium} = ErrorCategorizer.categorize_error({:error, %{status: 400}})
    end

    test "categorizes 404 as permanent with low severity" do
      assert {:permanent, :low} = ErrorCategorizer.categorize_error({:error, %{status: 404}})
    end

    test "categorizes 422 as permanent with medium severity" do
      assert {:permanent, :medium} = ErrorCategorizer.categorize_error({:error, %{status: 422}})
    end

    test "categorizes timeout as network with medium severity" do
      assert {:network, :medium} = ErrorCategorizer.categorize_error({:error, :timeout})
    end

    test "categorizes econnrefused as network with medium severity" do
      assert {:network, :medium} = ErrorCategorizer.categorize_error({:error, :econnrefused})
    end

    test "categorizes missing_api_key as configuration with critical severity" do
      assert {:configuration, :critical} =
               ErrorCategorizer.categorize_error({:error, :missing_api_key})
    end

    test "categorizes success responses" do
      assert {:success, :low} = ErrorCategorizer.categorize_error({:ok, %{status: 200}})
      assert {:success, :low} = ErrorCategorizer.categorize_error({:ok, %{status: 201}})
    end

    test "categorizes other 5xx as transient with high severity" do
      assert {:transient, :high} = ErrorCategorizer.categorize_error({:error, %{status: 500}})
      assert {:transient, :high} = ErrorCategorizer.categorize_error({:error, %{status: 599}})
    end

    test "categorizes unknown errors as permanent with medium severity" do
      assert {:permanent, :medium} =
               ErrorCategorizer.categorize_error({:error, "unknown error"})
    end
  end

  describe "retryable?/1" do
    test "returns true for transient errors" do
      assert ErrorCategorizer.retryable?({:error, %{status: 503}})
      assert ErrorCategorizer.retryable?({:error, %{status: 504}})
      assert ErrorCategorizer.retryable?({:error, %{status: 502}})
    end

    test "returns true for rate limit errors" do
      assert ErrorCategorizer.retryable?({:error, %{status: 429}})
    end

    test "returns true for network errors" do
      assert ErrorCategorizer.retryable?({:error, :timeout})
      assert ErrorCategorizer.retryable?({:error, :econnrefused})
    end

    test "returns false for authentication errors" do
      refute ErrorCategorizer.retryable?({:error, %{status: 401}})
      refute ErrorCategorizer.retryable?({:error, %{status: 403}})
    end

    test "returns false for configuration errors" do
      refute ErrorCategorizer.retryable?({:error, :missing_api_key})
    end

    test "returns false for permanent errors" do
      refute ErrorCategorizer.retryable?({:error, %{status: 400}})
      refute ErrorCategorizer.retryable?({:error, %{status: 404}})
      refute ErrorCategorizer.retryable?({:error, %{status: 422}})
    end

    test "returns false for success responses" do
      refute ErrorCategorizer.retryable?({:ok, %{status: 200}})
    end
  end
end
