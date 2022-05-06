library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART is
port(
	CLOCK_50 : in std_logic; -- 50 Mhz Clock
	SW : in std_logic_vector(9 downto 0); -- Switches
	KEY : in std_logic_vector(3 downto 0); -- Keys
	LEDR : out std_logic_vector(9 downto 0); -- Red LEDS
	LEDG : out std_logic_vector(7 downto 0); -- Green LEDS
	UART_TX : out std_logic; -- Transmitter
	UART_RX : in std_logic -- Receiver
);
end UART;

Architecture MAIN of UART is
signal TX_DATA : std_logic_vector(7 downto 0);
signal TX_START :std_logic:='0';
signal TX_BUSY : std_logic;
-- These are the missing signals to map them 
-----------------------------
component TX
port (
	CLK : in std_logic; -- 50Mhz Clock
	START : in std_logic; -- Start Bit
	BUSY : out std_logic; -- Busy signal (checks if the transmission is currently running)
	DATA : in std_logic_vector(7 downto 0); 
	TX_LINE : out std_logic		-- Actual transmission line TX_LINE that goes out of our FPGA board into PC
);
end component TX;
begin 

-- Connecting the component C1 to the main entity
C1 : TX port map (CLOCK_50,TX_START,TX_BUSY,TX_DATA,UART_TX); 
process (CLOCK_50)
begin
if (CLOCK_50'event and CLOCK_50='1') then 
	if (KEY(0)='0' and TX_BUSY='0') then -- Transmission is only triggered if key(0) is pressed and the transmitter is not busy
		TX_DATA <= SW (7 downto 0); -- read 8 first switches and send their status as an 8 binary number to the pc
		TX_START <= '1';
		LEDG <= TX_DATA; -- Green led will show the number in binary on the FPGA Board
	else
		TX_START <= '0';
	end if;
end if;
end process;
end MAIN;

