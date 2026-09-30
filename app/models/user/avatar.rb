module User::Avatar
  extend ActiveSupport::Concern

  AVATAR_COLORS = %w[
    #AF2E1B #CC6324 #3B4B59 #BFA07A #ED8008 #ED3F1C #BF1B1B #736B1E #D07B53
    #736356 #AD1D1D #BF7C2A #C09C6F #698F9C #7C956B #5D618F #3B3633 #67695E
  ].freeze

  def avatar_background_color
    AVATAR_COLORS[Zlib.crc32(to_param) % AVATAR_COLORS.size]
  end
end
