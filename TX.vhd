library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Transmitter component
entity TX is 
port (
	CLK : in std_logic; -- 50Mhz Clock
	START : in std_logic; -- Start Bit
	BUSY : out std_logic; -- Busy signal (checks if the transmission is currently running)
	DATA : in std_logic_vector(7 downto 0); 
	TX_lINE : out std_logic		-- Actual transmission line TX_LINE that goes out of our FPGA board into PC
);
end TX;


architecture MAIN of TX is 

signal PRSCL : integer range 0 to 5208:=0; -- Prescaler for the main clock
signal INDEX : integer range 0 to 9:=0; -- Select the bit we are going to send
signal DATAFLL : std_logic_Vector(9 downto 0); -- the 8-bit Data + start and stop bits
signal TX_FLG : std_logic:='0'; -- Starts the transmission process //initialize signal to 0
begin
	process(CLK)
	begin
		if (CLK'event and CLK='1') then 
			if(TX_FLG='0' and START='1') then -- The new transmission starts only if no communication is currently running and start is high 
				TX_FLG <= '1';
				BUSY <= '1';
				DATAFLL(0) <= '0'; -- Start bit
				DATAFLL(9) <= '1'; -- Stop Bit
				DATAFLL(8 downto 1) <= DATA;
			end if;
			if(TX_FLG = '1') then
				-- if the flag is ON we start sending data,
				-- since the common data rate for UART is 9600 bauds so we build a simple prescaler
				-- prescaler counts to 5208 (50^6/9600 = 5208)
				if(PRSCL < 5207) then 
					PRSCL <= PRSCL + 1;
				else 
					PRSCL <= 0;
				end if;
				-- prescaler hits 2600 we pass to TX_LINE the current bit 
				-- we increase the bit index by 1 if it is less than 9
				-- if it is already the 9th bit, the last bit is sent and the transmission is complete
				if(PRSCL <= 2607) then
					TX_LINE <= DATAFLL(INDEX);
					if(INDEX < 9) then 
						INDEX <= INDEX + 1;
					else 
						-- end of transmission we reset the flag the busy and index bit
						TX_FLG <= '0'; 
						BUSY <= '0';
						INDEX <= 0;
					end if;
				end if;
			end if;
		end if;
	end process;
end MAIN;