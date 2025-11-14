# frozen_string_literal: true

class AvatarService
  # Beautiful color palette for skin tones and features
  SKIN_COLORS = [
    "#FDBCB4", "#F8D5CC", "#E8A87C", "#D4A574", "#C68642",
    "#B87333", "#A0522D", "#8B4513", "#654321", "#3D2817"
  ].freeze

  HAIR_COLORS = [
    "#1A1A1A", "#3D2817", "#654321", "#8B4513", "#A0522D",
    "#D4A574", "#F4A460", "#FFD700", "#FF6347", "#FF1493",
    "#9370DB", "#4169E1", "#00CED1", "#32CD32", "#FF8C00"
  ].freeze

  BACKGROUND_COLORS = [
    "#6366F1", "#8B5CF6", "#EC4899", "#F43F5E", "#EF4444",
    "#F59E0B", "#10B981", "#14B8A6", "#06B6D4", "#3B82F6",
    "#A855F7", "#F97316", "#84CC16", "#22C55E", "#0EA5E9", "#6366F1"
  ].freeze

  EYE_COLORS = ["#1A1A1A", "#4169E1", "#32CD32", "#8B4513", "#FF6347"].freeze

  def self.generate_avatar_url(user)
    new(user).generate_avatar_url
  end

  def initialize(user)
    @user = user
    @identifier = user.identifier_for_avatar
  end

  def generate_avatar_url
    svg_content = generate_svg
    # Store SVG in database
    @user.update_column(:avatar_svg, svg_content)
    "/avatars/#{@user.id}"
  end

  def generate_svg(size: 200)
    config = get_cartoon_config
    generate_cartoon_svg(size, config)
  end

  private

  def hash_string(str)
    hash = 0
    str.each_char { |char| hash = ((hash << 5) - hash) + char.ord }
    hash.abs
  end

  def get_cartoon_config
    hash = hash_string(@identifier.downcase)
    
    {
      skin_color: SKIN_COLORS[hash % SKIN_COLORS.length],
      hair_color: HAIR_COLORS[(hash * 3) % HAIR_COLORS.length],
      eye_color: EYE_COLORS[(hash * 5) % EYE_COLORS.length],
      bg_color: BACKGROUND_COLORS[(hash * 7) % BACKGROUND_COLORS.length],
      face_shape: hash % 3, # 0: round, 1: oval, 2: square
      eye_style: (hash >> 4) % 4, # 0: normal, 1: big, 2: small, 3: closed
      mouth_style: (hash >> 6) % 4, # 0: smile, 1: big smile, 2: neutral, 3: surprised
      hair_style: (hash >> 8) % 6, # 0-5: different hair styles
      has_glasses: (hash >> 12) % 3 == 0, # 20% chance
      has_beard: (hash >> 14) % 4 == 0, # 25% chance
      has_accessory: (hash >> 16) % 3 == 0, # 33% chance
      accessory_type: (hash >> 18) % 3 # 0: hat, 1: cap, 2: headband
    }
  end

  def generate_cartoon_svg(size, config)
    center_x = size / 2
    center_y = size / 2
    
    <<~SVG
      <svg width="#{size}" height="#{size}" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" style="stop-color:#{config[:bg_color]};stop-opacity:1" />
            <stop offset="100%" style="stop-color:#{darken_color(config[:bg_color])};stop-opacity:1" />
          </linearGradient>
        </defs>
        
        <!-- Background circle -->
        <circle cx="#{center_x}" cy="#{center_y}" r="#{size / 2}" fill="url(#bgGrad)"/>
        
        #{render_face(size, center_x, center_y, config)}
        #{render_hair(size, center_x, center_y, config)}
        #{render_accessory(size, center_x, center_y, config)}
        #{render_glasses(size, center_x, center_y, config) if config[:has_glasses]}
        #{render_beard(size, center_x, center_y, config) if config[:has_beard]}
      </svg>
    SVG
  end

  def render_face(size, cx, cy, config)
    face_size = size * 0.7
    face_y = cy + size * 0.05
    
    case config[:face_shape]
    when 0 # Round
      face = %(<circle cx="#{cx}" cy="#{face_y}" r="#{face_size / 2}" fill="#{config[:skin_color]}" stroke="#{darken_color(config[:skin_color], 0.2)}" stroke-width="2"/>)
    when 1 # Oval
      face = %(<ellipse cx="#{cx}" cy="#{face_y}" rx="#{face_size * 0.45}" ry="#{face_size * 0.55}" fill="#{config[:skin_color]}" stroke="#{darken_color(config[:skin_color], 0.2)}" stroke-width="2"/>)
    else # Square
      face_size_adjusted = face_size * 0.85
      face = %(<rect x="#{cx - face_size_adjusted / 2}" y="#{face_y - face_size_adjusted / 2}" width="#{face_size_adjusted}" height="#{face_size_adjusted}" rx="#{face_size_adjusted * 0.2}" fill="#{config[:skin_color]}" stroke="#{darken_color(config[:skin_color], 0.2)}" stroke-width="2"/>)
    end
    
    eyes = render_eyes(size, cx, cy, config)
    mouth = render_mouth(size, cx, cy, config)
    nose = render_nose(size, cx, cy, config)
    
    "#{face}\n        #{eyes}\n        #{nose}\n        #{mouth}"
  end

  def render_eyes(size, cx, cy, config)
    eye_y = cy - size * 0.05
    eye_spacing = size * 0.15
    eye_size = case config[:eye_style]
               when 1 then size * 0.08  # Big
               when 2 then size * 0.04  # Small
               else size * 0.06         # Normal
               end
    
    if config[:eye_style] == 3 # Closed eyes
      %(<line x1="#{cx - eye_spacing}" y1="#{eye_y}" x2="#{cx - eye_spacing + eye_size}" y2="#{eye_y}" stroke="#{config[:eye_color]}" stroke-width="3" stroke-linecap="round"/>
        <line x1="#{cx + eye_spacing - eye_size}" y1="#{eye_y}" x2="#{cx + eye_spacing}" y2="#{eye_y}" stroke="#{config[:eye_color]}" stroke-width="3" stroke-linecap="round"/>)
    else
      left_eye = %(<circle cx="#{cx - eye_spacing}" cy="#{eye_y}" r="#{eye_size}" fill="#{config[:eye_color]}"/>)
      right_eye = %(<circle cx="#{cx + eye_spacing}" cy="#{eye_y}" r="#{eye_size}" fill="#{config[:eye_color]}"/>)
      
      # Add eye highlights
      highlight_size = eye_size * 0.3
      left_highlight = %(<circle cx="#{cx - eye_spacing - highlight_size * 0.5}" cy="#{eye_y - highlight_size * 0.5}" r="#{highlight_size}" fill="#FFFFFF" opacity="0.8"/>)
      right_highlight = %(<circle cx="#{cx + eye_spacing - highlight_size * 0.5}" cy="#{eye_y - highlight_size * 0.5}" r="#{highlight_size}" fill="#FFFFFF" opacity="0.8"/>)
      
      "#{left_eye}\n        #{right_eye}\n        #{left_highlight}\n        #{right_highlight}"
    end
  end

  def render_nose(size, cx, cy, config)
    nose_y = cy + size * 0.08
    nose_size = size * 0.03
    %(<ellipse cx="#{cx}" cy="#{nose_y}" rx="#{nose_size}" ry="#{nose_size * 1.5}" fill="#{darken_color(config[:skin_color], 0.15)}" opacity="0.6"/>)
  end

  def render_mouth(size, cx, cy, config)
    mouth_y = cy + size * 0.2
    mouth_width = size * 0.12
    
    case config[:mouth_style]
    when 0 # Smile
      %(<path d="M #{cx - mouth_width} #{mouth_y} Q #{cx} #{mouth_y + size * 0.05} #{cx + mouth_width} #{mouth_y}" stroke="#{config[:eye_color]}" stroke-width="3" fill="none" stroke-linecap="round"/>)
    when 1 # Big smile
      %(<path d="M #{cx - mouth_width * 1.2} #{mouth_y} Q #{cx} #{mouth_y + size * 0.08} #{cx + mouth_width * 1.2} #{mouth_y}" stroke="#{config[:eye_color]}" stroke-width="3" fill="none" stroke-linecap="round"/>)
    when 2 # Neutral
      %(<line x1="#{cx - mouth_width}" y1="#{mouth_y}" x2="#{cx + mouth_width}" y2="#{mouth_y}" stroke="#{config[:eye_color]}" stroke-width="3" stroke-linecap="round"/>)
    else # Surprised
      %(<circle cx="#{cx}" cy="#{mouth_y}" r="#{mouth_width * 0.6}" fill="#{config[:eye_color]}" opacity="0.7"/>)
    end
  end

  def render_hair(size, cx, cy, config)
    hair_y = cy - size * 0.25
    hair_width = size * 0.4
    
    case config[:hair_style]
    when 0 # Short spiky
      spikes = (0..4).map do |i|
        angle = (i - 2) * 0.3
        x = cx + Math.cos(angle) * hair_width * 0.6
        y = hair_y + Math.sin(angle) * size * 0.15
        %(<circle cx="#{x}" cy="#{y}" r="#{size * 0.06}" fill="#{config[:hair_color]}"/>)
      end.join("\n        ")
      spikes
    when 1 # Curly
      curls = (0..5).map do |i|
        angle = (i * Math::PI * 2) / 6
        x = cx + Math.cos(angle) * hair_width * 0.5
        y = hair_y + Math.sin(angle) * size * 0.1
        %(<circle cx="#{x}" cy="#{y}" r="#{size * 0.05}" fill="#{config[:hair_color]}"/>)
      end.join("\n        ")
      curls
    when 2 # Long straight
      %(<rect x="#{cx - hair_width * 0.6}" y="#{hair_y}" width="#{hair_width * 1.2}" height="#{size * 0.3}" fill="#{config[:hair_color]}"/>
        <ellipse cx="#{cx}" cy="#{hair_y}" rx="#{hair_width * 0.6}" ry="#{size * 0.08}" fill="#{config[:hair_color]}"/>)
    when 3 # Wavy
      %(<path d="M #{cx - hair_width} #{hair_y} Q #{cx - hair_width * 0.5} #{hair_y - size * 0.05} #{cx} #{hair_y} T #{cx + hair_width} #{hair_y}" stroke="#{config[:hair_color]}" stroke-width="#{size * 0.08}" fill="none" stroke-linecap="round"/>
        <path d="M #{cx - hair_width} #{hair_y + size * 0.05} Q #{cx - hair_width * 0.5} #{hair_y} #{cx} #{hair_y + size * 0.05} T #{cx + hair_width} #{hair_y + size * 0.05}" stroke="#{config[:hair_color]}" stroke-width="#{size * 0.08}" fill="none" stroke-linecap="round"/>)
    when 4 # Mohawk
      %(<path d="M #{cx} #{hair_y} L #{cx - size * 0.05} #{hair_y - size * 0.2} L #{cx + size * 0.05} #{hair_y - size * 0.2} Z" fill="#{config[:hair_color]}"/>
        <rect x="#{cx - size * 0.06}" y="#{hair_y - size * 0.2}" width="#{size * 0.12}" height="#{size * 0.15}" fill="#{config[:hair_color]}"/>)
    else # Ponytail
      %(<circle cx="#{cx}" cy="#{hair_y}" r="#{hair_width * 0.5}" fill="#{config[:hair_color]}"/>
        <ellipse cx="#{cx + hair_width * 0.4}" cy="#{hair_y + size * 0.1}" rx="#{size * 0.04}" ry="#{size * 0.15}" fill="#{config[:hair_color]}"/>)
    end
  end

  def render_glasses(size, cx, cy, config)
    eye_y = cy - size * 0.05
    eye_spacing = size * 0.15
    glass_size = size * 0.1
    
    %(<circle cx="#{cx - eye_spacing}" cy="#{eye_y}" r="#{glass_size}" fill="none" stroke="#{config[:eye_color]}" stroke-width="3"/>
      <circle cx="#{cx + eye_spacing}" cy="#{eye_y}" r="#{glass_size}" fill="none" stroke="#{config[:eye_color]}" stroke-width="3"/>
      <line x1="#{cx - eye_spacing + glass_size}" y1="#{eye_y}" x2="#{cx + eye_spacing - glass_size}" y2="#{eye_y}" stroke="#{config[:eye_color]}" stroke-width="3"/>)
  end

  def render_beard(size, cx, cy, config)
    beard_y = cy + size * 0.25
    beard_width = size * 0.2
    
    %(<path d="M #{cx - beard_width} #{beard_y} Q #{cx} #{beard_y + size * 0.1} #{cx + beard_width} #{beard_y}" stroke="#{config[:hair_color]}" stroke-width="#{size * 0.04}" fill="none" stroke-linecap="round"/>
      <path d="M #{cx - beard_width * 0.7} #{beard_y + size * 0.02} Q #{cx} #{beard_y + size * 0.08} #{cx + beard_width * 0.7} #{beard_y + size * 0.02}" stroke="#{config[:hair_color]}" stroke-width="#{size * 0.03}" fill="none" stroke-linecap="round"/>)
  end

  def render_accessory(size, cx, cy, config)
    return "" unless config[:has_accessory]
    
    accessory_y = cy - size * 0.35
    
    case config[:accessory_type]
    when 0 # Hat
      %(<ellipse cx="#{cx}" cy="#{accessory_y}" rx="#{size * 0.25}" ry="#{size * 0.08}" fill="#{config[:bg_color]}" opacity="0.8"/>
        <rect x="#{cx - size * 0.25}" y="#{accessory_y - size * 0.05}" width="#{size * 0.5}" height="#{size * 0.1}" fill="#{config[:bg_color]}" opacity="0.8"/>)
    when 1 # Cap
      %(<path d="M #{cx - size * 0.25} #{accessory_y} Q #{cx} #{accessory_y - size * 0.1} #{cx + size * 0.25} #{accessory_y}" stroke="#{config[:bg_color]}" stroke-width="#{size * 0.06}" fill="none" stroke-linecap="round"/>
        <ellipse cx="#{cx}" cy="#{accessory_y}" rx="#{size * 0.25}" ry="#{size * 0.05}" fill="#{config[:bg_color]}" opacity="0.8"/>)
    else # Headband
      %(<ellipse cx="#{cx}" cy="#{accessory_y}" rx="#{size * 0.3}" ry="#{size * 0.04}" fill="#{config[:bg_color]}" opacity="0.7"/>)
    end
  end

  def darken_color(color, factor = 0.2)
    # Simple darkening by reducing RGB values
    hex = color.gsub("#", "")
    r = [hex[0..1].to_i(16) * (1 - factor), 0].max.to_i
    g = [hex[2..3].to_i(16) * (1 - factor), 0].max.to_i
    b = [hex[4..5].to_i(16) * (1 - factor), 0].max.to_i
    format("#%02X%02X%02X", r, g, b)
  end

  # Generate SVG content (stored in database)
  def generate_avatar_svg
    generate_svg
  end
end
