use Croma
alias Croma.Result, as: R

defmodule RaftedValue.LogEntry do
  alias RaftedValue.{TermNumber, LogIndex, Config}
  @type t :: {TermNumber.t, LogIndex.t, :command        , {GenServer.from, Data.command_arg, reference}}
           | {TermNumber.t, LogIndex.t, :query          , {GenServer.from, Data.query_arg}}
           | {TermNumber.t, LogIndex.t, :change_config  , Config.t}
           | {TermNumber.t, LogIndex.t, :leader_elected , pid}
           | {TermNumber.t, LogIndex.t, :add_follower   , pid}
           | {TermNumber.t, LogIndex.t, :remove_follower, pid}

  defun validate(v :: any) :: R.t(t) do
    {_, _, _, _} = t -> {:ok, t}
    _                -> {:error, {:invalid_value, [__MODULE__]}}
  end

  defp entry_type_to_tag(:command        ), do: 0
  defp entry_type_to_tag(:query          ), do: 1
  defp entry_type_to_tag(:change_config  ), do: 2
  defp entry_type_to_tag(:leader_elected ), do: 3
  defp entry_type_to_tag(:add_follower   ), do: 4
  defp entry_type_to_tag(:remove_follower), do: 5

  defp tag_to_entry_type(0), do: {:ok, :command        }
  defp tag_to_entry_type(1), do: {:ok, :query          }
  defp tag_to_entry_type(2), do: {:ok, :change_config  }
  defp tag_to_entry_type(3), do: {:ok, :leader_elected }
  defp tag_to_entry_type(4), do: {:ok, :add_follower   }
  defp tag_to_entry_type(5), do: {:ok, :remove_follower}
  defp tag_to_entry_type(_), do: :error

  defun to_binary({term, index, entry_type, others} :: t) :: binary do
    bin = :erlang.term_to_binary(others)
    <<term :: size(64), index :: size(64), entry_type_to_tag(entry_type) :: size(8), byte_size(bin) :: size(64), bin :: binary>>
  end

  defun extract_from_binary(bin :: binary) :: nil | {t, rest :: binary} do
    with <<term :: size(64), index :: size(64), type_tag :: size(8), size :: size(64)>> <> rest1 <- bin,
         {:ok, entry_type} <- tag_to_entry_type(type_tag),
         <<others_bin :: binary-size(size) >> <> rest2 <- rest1 do
      try do
        {{term, index, entry_type, :erlang.binary_to_term(others_bin)}, rest2}
      rescue
        ArgumentError -> nil
      end
    else
      _ -> nil
    end
  end
end