library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_rx is
    generic(
        BAUD_CLK_TICKS_x16: integer := 1); -- BAUD_CLK_TICKS_x16 = (Horloge / Debit Baud*16) (Dans ce cas pour 1 Front montant on avance d'echantillon)

    port(
        clk            : in  std_logic; -- Horloge Principal
        reset          : in  std_logic;
        rx_data_in     : in  std_logic; -- Donnée d'entré en série 
        rx_data_out    : out std_logic_vector (7 downto 0) -- Donnée de sortie en parallèle
        );
end UART_rx;


architecture Behavioral of UART_rx is

    type rx_states_t is (IDLE, START, DATA, STOP);-- Idle stat, Start bit, Stop Bit and data
    signal rx_state: rx_states_t := IDLE; -- état initial IDLE

    signal horloge_baud_rate_x16  : std_logic := '0'; -- Nouvelle Horloge échantillonée
    signal rx_stored_data     : std_logic_vector(7 downto 0) := (others => '0');

begin

-- Créer une horloge échantilloné, cette horloge est 16 fois plus rapide que l'horloge de baud
-- Nombre_de_cycle = (Horloge / Debit Baud*16)
    horloge_baud_rate_x16_generator: process(clk)
    variable Compteur_x16: integer range 0 to (BAUD_CLK_TICKS_x16 - 1) := (BAUD_CLK_TICKS_x16 - 1);
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                horloge_baud_rate_x16 <= '0';
                Compteur_x16 := (BAUD_CLK_TICKS_x16 - 1);
            else
                if (Compteur_x16 = 0) then
                    horloge_baud_rate_x16 <= '1';
                    Compteur_x16 := (BAUD_CLK_TICKS_x16 - 1);
                else
                    horloge_baud_rate_x16 <= '0';
                    Compteur_x16 := Compteur_x16 - 1;
                end if;
            end if;
        end if;
    end process horloge_baud_rate_x16_generator;

--  UART_rx_etat represente l'état de bit
-- four states (IDLE, START, DATA, STOP). See inline comments for more details.
    UART_rx_etat: process(clk)
        variable bit_duration_count : integer range 0 to 15 := 0; -- Compteur d'échantillon
        variable bit_count          : integer range 0 to 7  := 0; -- Compteur de bit
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                rx_state <= IDLE;
                rx_stored_data <= (others => '0');
                rx_data_out <= (others => '0');
                bit_duration_count := 0;
                bit_count := 0; 
            else
                if (horloge_baud_rate_x16 = '1') then     -- Le block s'active lors d'une transition de la nouvelle horloge (horloge_baud_rate_x16)
                    case rx_state is

                        when IDLE =>

                            rx_stored_data <= (others => '0');    -- Vider le register de donnée recu
                            bit_duration_count := 0;              -- reset counters
                            bit_count := 0;

                            if (rx_data_in = '0') then             -- Detection de start bit '0'
                                rx_state <= START;                 -- Transition à l'état start
                            end if;

                        when START =>

                            if (rx_data_in = '0') then             -- Verification de la présence du START bit
                                if (bit_duration_count = 7) then   -- On attend la moitié de cycle de debit de baud (moitié de bit)
                                    rx_state <= DATA;              -- moitié de START Bit
                                    bit_duration_count := 0;		 -- Réinitialisation du compteur d'échantillon
                                else
                                    bit_duration_count := bit_duration_count + 1;
                                end if;
                            else
                                rx_state <= IDLE;                  -- Fausse alarme, pas de start bit
                            end if;

                        when DATA =>

                            if (bit_duration_count = 15) then                -- En attend un cycle de debit de baud
                                rx_stored_data(bit_count) <= rx_data_in;     -- remplissage de registre de réception d'un bit reçu.
                                bit_duration_count := 0;
                                if (bit_count = 7) then                      -- lorsque tous les 8 bits sont reçus on passe à l'état STOP
                                    rx_state <= STOP;
                                    bit_duration_count := 0;
                                else
                                    bit_count := bit_count + 1;
                                end if;
                            else
                                bit_duration_count := bit_duration_count + 1;
                            end if;

                        when STOP =>
                            if (bit_duration_count = 15) then      -- fin de un cycle de baud
                                rx_data_out <= rx_stored_data;     -- Transfert de donné vers l'application eterne
                                rx_state <= IDLE;						 -- Retour à l'état initial
                            else
                                bit_duration_count := bit_duration_count + 1;
                            end if;

                        when others =>
                            rx_state <= IDLE;
                    end case;
                end if;
            end if;
        end if;
    end process UART_rx_etat;

end Behavioral;
