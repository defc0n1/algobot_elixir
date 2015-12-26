defmodule BOT2.MovingAverageCalc do
  @moduledoc """
  Calculates the average price between two points in time.  Due to the fact that
  ticks arrive at irregular intervals, ticks are weighted depending on
  how long the price remains at that level until the next tick.
  """
  def calc_all(conn, symbol, timestamp) do
    ma_index = Iset.append(conn, "sma_#{symbol}", "timestamps", timestamp)
    calc_one(conn, timestamp, symbol, 30, ma_index)
    calc_one(conn, timestamp, symbol, 120, ma_index)
    calc_one(conn, timestamp, symbol, 600, ma_index)
  end

  # casey what does this method name even mean?
  def exact_ok?(indexes) do
    Application.get_env(:bot2, :accurate_averages) && length(indexes) > 1 && hd(indexes) != 0
  end

  def calc_one(conn, timestamp, symbol, range, ma_index) do
    {indexes, timestamps} = Iset.range_by_element(conn, "ticks_#{String.downcase(symbol)}", "timestamps", timestamp-range, timestamp)
    if indexes != [] do
      prices = Iset.range_by_index(conn, "ticks_#{String.downcase(symbol)}", "bids", hd(indexes), List.last(indexes))

      prices = prices |> Enum.map(fn(x) ->
        {num, ""} = Float.parse(x); num
      end)
      timestamps = Enum.map(timestamps, fn(x) ->
        {num, ""} = Float.parse(x); num
      end)
      indexes = Enum.map(indexes, fn(x) ->
        {num, ""} = Integer.parse(x); num
      end)

      if exact_ok?(indexes) do
        # prev_timestamp = Iset.get(conn, "ticks_#{String.downcase(symbol)}", "timestamps", hd(indexes)-1)
        {prev_price, ""} = Float.parse Iset.get(conn, "ticks_#{String.downcase(symbol)}", "bids", hd(indexes)-1)

        total_time = range
        tick_range = List.last(timestamps) - List.first(timestamps)
        prev_time = range - (range - tick_range)
        total = prev_price * (prev_time / total_time)
      else
        total = 0
        total_time = List.last(timestamps) - List.first(timestamps)
      end

      average = do_calculation(prices, timestamps, total, total_time)
      Iset.add(conn, "sma_#{symbol}", "data_#{range}", average, ma_index)
      #TODO: Send average to necessary places
    else
      Iset.add(conn, "sma_#{symbol}", "data_#{range}", nil, ma_index)
    end
  end

  # jaden code: talk to casey to figure out what this shit is
  def do_calculation(prices, timestamps, total, total_time) do
    if length(prices) > 1 do
      [firstPrice | prices] = prices
      [firstTimestamp | timestamps] = timestamps

      tickLength = List.first(timestamps) - firstTimestamp
      total = total + (firstPrice * (tickLength / total_time))

      if length(timestamps) > 1 do
        do_calculation(prices, timestamps, total, total_time)
      else
        total
      end
    else
      if total == 0 do
        List.first(prices)
      else
        firstPrice = List.first(prices)
        firstTimestamp = List.first(timestamps)

        tickLength = List.first(timestamps) - firstTimestamp
        total + (firstPrice * (tickLength / total_time))
      end
    end
  end
end