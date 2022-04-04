defmodule Cirlute.TB6612 do
  @moduledoc """
  Elixir driver for TB6612 motor driver board.
  """

  alias Circuits.GPIO
  alias __MODULE__, as: T

  @behaviour Cirlute.Motor

  @enforce_keys [
    :pwm_module,
    :pwm_driver,
    :pwm_channel,
    :pwm_frequency,
    :direction_channel,
    :forward_signal,
    :backward_signal,
    :gpio_handle,
    :speed
  ]
  defstruct pwm_module: nil,
            pwm_driver: nil,
            pwm_channel: 0,
            pwm_frequency: 60,
            direction_channel: nil,
            forward_signal: 1,
            backward_signal: 0,
            gpio_handle: nil,
            speed: 0

  def new(opts) do
    with direction_channel <- opts[:direction_channel] || nil,
         {:direction_channel_is_non_neg_int, true} <-
           {:direction_channel_is_non_neg_int,
            is_integer(direction_channel) and direction_channel >= 0},
         pwm_channel <- opts[:pwm_channel] || nil,
         {:pwm_channel_is_non_neg_int, true} <-
           {:pwm_channel_is_non_neg_int, is_integer(pwm_channel) and pwm_channel >= 0},
         direction_signal_inverted <- opts[:direction_signal_inverted] || false,
         {:direction_signal_inverted_is_bool, true} <-
           {:direction_signal_inverted_is_bool, is_boolean(direction_signal_inverted)},
         {forward_signal, backward_signal} <- direction_signal(direction_signal_inverted),
         [pwm_module, pwm_address, pwm_i2c_bus, pwm_freq] <-
           Tuple.to_list(opts[:pwm_opts] || {:error, "invalid pwm_opts"}),
         {:ok, pwm_driver} <-
           Kernel.apply(pwm_module, :new, [pwm_address, pwm_i2c_bus, pwm_freq]),
         {:ok, gpio_handle} = GPIO.open(direction_channel, :output) do
      {:ok,
       %T{
         pwm_module: pwm_module,
         pwm_driver: pwm_driver,
         pwm_channel: pwm_channel,
         pwm_frequency: pwm_freq,
         direction_channel: direction_channel,
         forward_signal: forward_signal,
         backward_signal: backward_signal,
         gpio_handle: gpio_handle,
         speed: 0
       }}
    else
      {:error, reason} ->
        {:error, reason}

      {:direction_channel_is_non_neg_int, false} ->
        {:error, "expecting :direction_channel option to be a non-negative integer value"}

      {:pwm_channel_is_non_neg_int, false} ->
        {:error, "expecting :pwm_channel option to be a non-negative integer value"}

      {:direction_signal_inverted_is_bool, false} ->
        {:error, "expecting :direction_signal_inverted option to be a boolean value"}
    end
  end

  def speed(%T{speed: speed}) do
    {:ok, speed}
  end

  def set_speed(self = %T{}, speed) when is_number(speed) and speed > 0 do
    speed =
      if speed > 100 do
        100
      else
        speed
      end

    forward(self, speed)
  end

  def set_speed(self = %T{}, speed) when is_number(speed) and speed == 0 do
    stop(self)
  end

  def set_speed(self = %T{}, speed) when is_number(speed) and speed < 0 do
    speed =
      if speed < -100 do
        100
      else
        abs(speed)
      end

    backward(self, speed)
  end

  def forward(self = %T{}, speed) when is_number(speed) and 0 <= speed and speed <= 100 do
    with :ok <- GPIO.write(self.gpio_handle, self.forward_signal),
         _ <- :timer.sleep(5),
         min_pwm <- Kernel.apply(self.pwm_module, :min_pwm, []),
         max_pwm <- Kernel.apply(self.pwm_module, :max_pwm, []),
         pwm_value <- map_speed_to_pwm(speed, 0, 100, min_pwm, max_pwm),
         :ok <-
           Kernel.apply(self.pwm_module, :set_pwm, [self.pwm_driver, self.pwm_channel, pwm_value]) do
      {:ok, %T{self | speed: speed}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def backward(self = %T{}, speed) when is_number(speed) and 0 <= speed and speed <= 100 do
    with :ok <- GPIO.write(self.gpio_handle, self.backward_signal),
         _ <- :timer.sleep(5),
         min_pwm <- Kernel.apply(self.pwm_module, :min_pwm, []),
         max_pwm <- Kernel.apply(self.pwm_module, :max_pwm, []),
         pwm_value <- map_speed_to_pwm(speed, 0, 100, min_pwm, max_pwm),
         :ok <-
           Kernel.apply(self.pwm_module, :set_pwm, [self.pwm_driver, self.pwm_channel, pwm_value]) do
      {:ok, %T{self | speed: -speed}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def stop(self = %T{}) do
    with min_pwm <- Kernel.apply(self.pwm_module, :min_pwm, []),
         :ok <-
           Kernel.apply(self.pwm_module, :set_pwm, [self.pwm_driver, self.pwm_channel, min_pwm]) do
      {:ok, %T{self | speed: 0}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp map_speed_to_pwm(x, in_min, in_max, out_min, out_max) do
    trunc((x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min)
  end

  defp direction_signal(true) do
    {0, 1}
  end

  defp direction_signal(false) do
    {1, 0}
  end
end
