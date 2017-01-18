defmodule Cerbas.Cron do
  @moduledoc false
  import Cerbas

  def crontab_entry({entry, request}, counter) do

    gseconds = :os.timestamp 
      |> :calendar.now_to_datetime 
      |> :calendar.datetime_to_gregorian_seconds
    nseconds = gseconds - 60
    dt_base = nseconds 
      |> :calendar.gregorian_seconds_to_datetime

    {{year1,month1,day1}, {hour1,minutes1,_}} = 
      now = :os.timestamp |> :calendar.now_to_datetime
    
    now1 = {{year1,month1,day1},{hour1,minutes1,0}}
    
    {{year, month, day},{hour, minutes, seconds}} = 
      crontime  = ExCron.next(entry, dt_base) 

    if crontime == now1 do
      key = :crypto.hash(:md5, 
        "#{zformat(year,4)}" <> 
        "#{zformat(month,2)}" <> 
        "#{zformat(day,2)}" <> 
        "#{zformat(hour,2)}" <> 
        "#{zformat(minutes,2)} " <> 
        "#{request}"  
      )

      case Agent.get(reg_tuple("cronmap"), fn val -> Map.get(val, key) end) do
        nil -> Agent.update(reg_tuple("cronmap"), fn val -> Map.put(val,key,true) end)
          case request |> get_request_parts("") |> Cerbas.Dispatcher.dispatch do
            {:error, _} -> "error" |> color_info(:red) 
              :error
            val -> "ok" |> color_info(:green)
              :ok
            _ -> :error
          end 
        _ -> :skipped
      end
    else
      :skipped
    end 

  end

  def read_cron_file(filename \\ "CRONTAB", counter \\ 1) do
    if counter == 1 do
      Agent.start_link(fn -> %{} end, name: reg_tuple("cronmap"))
    end
    case File.open(filename, [:read]) do
      {:ok, file} -> 
        file
        |> IO.stream(:line) 
        |> Stream.map(&(String.split(&1, "|"))) 
        |> Stream.map(fn [x | y] -> 
        spawn_link __MODULE__, :crontab_entry, [{String.trim_trailing(x), y}, counter]
        end)
        |> Enum.to_list
        File.close(file)
      _ -> nil
    end
    :timer.sleep 50
    read_cron_file(filename, counter + 1)
  end

  def crondispatcher(filename) do
    :timer.sleep 1000
    "Cronjob dispatcher started" |> color_info(:yellow)
    read_cron_file(filename)
  end
end
