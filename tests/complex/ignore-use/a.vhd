library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- library work;
-- use work.vhsnunzip_int_pkg.all;

-- pragma vhdeps ignore package vcomponents
library unisim;
use unisim.vcomponents.all;

-- pragma vhdeps ignore package vcomponents
library unimacro;
use unimacro.vcomponents.all;

-- Primitive instantiation of a Xilinx URAM or collection of 8 BRAMs. 4k deep,
-- 8+1 bytes wide, for 32+4kiB of storage, with two R/W access ports. The total
-- read latency is exactly 3 cycles.
entity vhsnunzip_ram is
  generic (

    -- Select "URAM" to instantiate an UltraRAM block, or "BRAM" to use eight
    -- 36kib block RAMs.
    RAM_STYLE   : string := "URAM"

  );
  port (
    clk         : in  std_logic;
    reset       : in  std_logic;

    -- Access port A.
    a_cmd       : in  ram_command;
    a_resp      : out ram_response;

    -- Access port B.
    b_cmd       : in  ram_command;
    b_resp      : out ram_response

  );
end vhsnunzip_ram;

architecture behavior of vhsnunzip_ram is
begin

  -- Implementation for URAMs.
  uram_gen: if RAM_STYLE = "URAM" generate
    signal a_addr     : std_logic_vector(22 downto 0);
    signal a_wdat     : std_logic_vector(71 downto 0);
    signal a_rval_r   : std_logic;
    signal a_rval_rr  : std_logic;
    signal a_rval_rrr : std_logic;
    signal a_rdat     : std_logic_vector(71 downto 0);

    signal b_addr     : std_logic_vector(22 downto 0);
    signal b_wdat     : std_logic_vector(71 downto 0);
    signal b_rval_r   : std_logic;
    signal b_rval_rr  : std_logic;
    signal b_rval_rrr : std_logic;
    signal b_rdat     : std_logic_vector(71 downto 0);
  begin

    a_cmd_connect_proc: process (a_cmd) is
    begin
      a_addr <= std_logic_vector(resize(a_cmd.addr, 23));
      for byte in 0 to 7 loop
        a_wdat(byte*8+7 downto byte*8) <= a_cmd.wdat(byte);
      end loop;
      a_wdat(71 downto 64) <= a_cmd.wctrl;
    end process;

    b_cmd_connect_proc: process (b_cmd) is
    begin
      b_addr <= std_logic_vector(resize(b_cmd.addr, 23));
      for byte in 0 to 7 loop
        b_wdat(byte*8+7 downto byte*8) <= b_cmd.wdat(byte);
      end loop;
      b_wdat(71 downto 64) <= b_cmd.wctrl;
    end process;

    -- pragma vhdeps ignore component uram288_base
    uram_inst : uram288_base
      generic map (
        IREG_PRE_A  => "TRUE",
        IREG_PRE_B  => "TRUE",
        OREG_A      => "TRUE",
        OREG_B      => "TRUE"
      )
      port map (
        clk         => clk,
        rst_a       => '0',
        rst_b       => '0',
        sleep       => '0',

        -- Port A interface.
        en_a        => a_cmd.valid,
        addr_a      => a_addr,
        rdb_wr_a    => a_cmd.wren,
        bwe_a       => "111111111",
        din_a       => a_wdat,
        dout_a      => a_rdat,

        -- Port B interface.
        en_b        => b_cmd.valid,
        addr_b      => b_addr,
        rdb_wr_b    => b_cmd.wren,
        bwe_b       => "111111111",
        din_b       => b_wdat,
        dout_b      => b_rdat,

        -- Port A control bits.
        oreg_ce_a         => '1',
        oreg_ecc_ce_a     => '1',
        inject_dbiterr_a  => '0',
        inject_sbiterr_a  => '0',

        -- Port B control bits.
        oreg_ce_b         => '1',
        oreg_ecc_ce_b     => '1',
        inject_dbiterr_b  => '0',
        inject_sbiterr_b  => '0'
      );

    a_resp_connect_proc: process (a_rdat, a_rval_rr, a_rval_rrr) is
    begin
      for byte in 0 to 7 loop
        a_resp.rdat(byte) <= a_rdat(byte*8+7 downto byte*8);
      end loop;
      a_resp.rctrl <= a_rdat(71 downto 64);
      a_resp.valid <= a_rval_rrr;
      a_resp.valid_next <= a_rval_rr;
    end process;

    b_resp_connect_proc: process (b_rdat, b_rval_rr, b_rval_rrr) is
    begin
      for byte in 0 to 7 loop
        b_resp.rdat(byte) <= b_rdat(byte*8+7 downto byte*8);
      end loop;
      b_resp.rctrl <= b_rdat(71 downto 64);
      b_resp.valid <= b_rval_rrr;
      b_resp.valid_next <= b_rval_rr;
    end process;

    resp_valid_proc: process (clk) is
    begin
      if rising_edge(clk) then
        a_rval_r <= a_cmd.valid and not a_cmd.wren;
        b_rval_r <= b_cmd.valid and not b_cmd.wren;
        a_rval_rr <= a_rval_r;
        b_rval_rr <= b_rval_r;
        a_rval_rrr <= a_rval_rr;
        b_rval_rrr <= b_rval_rr;
        if reset = '1' then
          a_rval_r <= '0';
          b_rval_r <= '0';
          a_rval_rr <= '0';
          b_rval_rr <= '0';
          a_rval_rrr <= '0';
          b_rval_rrr <= '0';
        end if;
      end if;
    end process;

  end generate;

  bram_gen: if RAM_STYLE = "BRAM" generate
    type data_array is array (natural range <>) of std_logic_vector(8 downto 0);

    signal a_ena      : std_logic;
    signal a_addr     : std_logic_vector(11 downto 0);
    signal a_we       : std_logic_vector(0 downto 0);
    signal a_rval_r   : std_logic;
    signal a_rval_rr  : std_logic;
    signal a_rval_rrr : std_logic;
    signal a_wdat     : data_array(0 to 7);
    signal a_rdat     : data_array(0 to 7);

    signal b_ena      : std_logic;
    signal b_addr     : std_logic_vector(11 downto 0);
    signal b_we       : std_logic_vector(0 downto 0);
    signal b_rval_r   : std_logic;
    signal b_rval_rr  : std_logic;
    signal b_rval_rrr : std_logic;
    signal b_wdat     : data_array(0 to 7);
    signal b_rdat     : data_array(0 to 7);

  begin

    a_cmd_connect_proc: process (clk) is
    begin
      if rising_edge(clk) then
        a_ena <= a_cmd.valid;
        a_addr <= std_logic_vector(a_cmd.addr);
        a_we <= (others => a_cmd.wren);
        for byte in 0 to 7 loop
          a_wdat(byte)(7 downto 0) <= a_cmd.wdat(byte);
          a_wdat(byte)(8) <= a_cmd.wctrl(byte);
        end loop;
      end if;
    end process;

    b_cmd_connect_proc: process (clk) is
    begin
      if rising_edge(clk) then
        b_ena <= b_cmd.valid;
        b_addr <= std_logic_vector(b_cmd.addr);
        b_we <= (others => b_cmd.wren);
        for byte in 0 to 7 loop
          b_wdat(byte)(7 downto 0) <= b_cmd.wdat(byte);
          b_wdat(byte)(8) <= b_cmd.wctrl(byte);
        end loop;
      end if;
    end process;

    byte_gen: for byte in 0 to 7 generate
    begin
      -- pragma vhdeps ignore component bram_tdp_macro
      bram: bram_tdp_macro
        generic map (
          BRAM_SIZE     => "36Kb",
          DOA_REG       => 1,
          DOB_REG       => 1,
          READ_WIDTH_A  => 9,
          READ_WIDTH_B  => 9,
          WRITE_WIDTH_A => 9,
          WRITE_WIDTH_B => 9
        )
        port map (
          clka          => clk,
          clkb          => clk,
          rsta          => '0',
          rstb          => '0',
          regcea        => '1',
          regceb        => '1',

          ena           => a_ena,
          addra         => a_addr,
          wea           => a_we,
          dia           => a_wdat(byte),
          doa           => a_rdat(byte),

          enb           => b_ena,
          addrb         => b_addr,
          web           => b_we,
          dib           => b_wdat(byte),
          dob           => b_rdat(byte)
        );
    end generate;

    a_resp_connect_proc: process (a_rdat, a_rval_rr, a_rval_rrr) is
    begin
      for byte in 0 to 7 loop
        a_resp.rdat(byte) <= a_rdat(byte)(7 downto 0);
        a_resp.rctrl(byte) <= a_rdat(byte)(8);
      end loop;
      a_resp.valid <= a_rval_rrr;
      a_resp.valid_next <= a_rval_rr;
    end process;

    b_resp_connect_proc: process (b_rdat, b_rval_rr, b_rval_rrr) is
    begin
      for byte in 0 to 7 loop
        b_resp.rdat(byte) <= b_rdat(byte)(7 downto 0);
        b_resp.rctrl(byte) <= b_rdat(byte)(8);
      end loop;
      b_resp.valid <= b_rval_rrr;
      b_resp.valid_next <= b_rval_rr;
    end process;

    resp_valid_proc: process (clk) is
    begin
      if rising_edge(clk) then
        a_rval_r <= a_cmd.valid and not a_cmd.wren;
        b_rval_r <= b_cmd.valid and not b_cmd.wren;
        a_rval_rr <= a_rval_r;
        b_rval_rr <= b_rval_r;
        a_rval_rrr <= a_rval_rr;
        b_rval_rrr <= b_rval_rr;
        if reset = '1' then
          a_rval_r <= '0';
          b_rval_r <= '0';
          a_rval_rr <= '0';
          b_rval_rr <= '0';
          a_rval_rrr <= '0';
          b_rval_rrr <= '0';
        end if;
      end if;
    end process;

  end generate;

end behavior;
