defmodule BlockScoutWeb.StakesHelpers do
  @moduledoc """
  Helpers for staking templates
  """
  alias Explorer.Chain.{BlockNumberCache, Wei}
  alias Timex.Duration

  def amount_ratio(pool) do
    {:ok, zero_wei} = Wei.cast(0)

    case pool do
      %{staked_amount: ^zero_wei} ->
        0

      %{staked_amount: staked_amount, self_staked_amount: self_staked} ->
        amount = Decimal.to_float(staked_amount.value)
        self = Decimal.to_float(self_staked.value)
        self / amount * 100
    end
  end

  def estimated_unban_day(banned_until, average_block_time) do
    block_time = Duration.to_seconds(average_block_time)

    try do
      during_sec = (banned_until - BlockNumberCache.max_number()) * block_time
      now = DateTime.utc_now() |> DateTime.to_unix()
      date = DateTime.from_unix!(trunc(now + during_sec))
      Timex.format!(date, "%d %b %Y", :strftime)
    rescue
      _e ->
        DateTime.utc_now()
        |> Timex.format!("%d %b %Y", :strftime)
    end
  end

  def epoch_end_sec(epoch_end, average_block_time) do
    block_time = Duration.to_seconds(average_block_time)
    block_time * epoch_end
  end

  def list_title(:validator), do: "Validators"
  def list_title(:active), do: "Active Pools"
  def list_title(:inactive), do: "Inactive Pools"

  def minus_wei(wei1, wei2) do
    Wei.sub(wei1, wei2)
  end
end
