module DB

  def self.get_raw_hero_data
    File.read('hero_stats/hero_search.txt').each_line do |heroes|
      hero_stats = heroes
    end
    hero_stats
  end

  def self.get_json_hero_data
    File.read('hero_stats/hero_search.json').each_line do |heroes|
      return JSON.parse(heroes)
    end
  end

  def self.get_icon(hero_name)
    hero = hero_name.downcase.gsub("-", "").gsub(" ", "_")
    "/assets/hero_portraits/#{hero}_full.png"
  end

  def self.build_heroes
    heroes = Hero.get_json_hero_data
    heroes.each do |hero|

      h = Hero.find_or_initialize_by(name: hero["name"])

      h.valve_id         = hero["valve_id"]
      h.radiant_team     = hero["radiant_team"]
      h.primary_stat     = hero["primary_stat"]
      h.str              = hero["str"].to_i
      h.agi              = hero["agi"].to_i
      h.int              = hero["int"].to_i
      h.str_per_lvl      = hero["str_per_lvl"].to_f
      h.agi_per_lvl      = hero["agi_per_lvl"].to_f
      h.int_per_lvl      = hero["int_per_lvl"].to_f
      h.hp               = hero["hp"].to_i
      h.mp               = hero["mp"].to_i
      h.min_dmg          = hero["min_dmg"].to_i
      h.max_dmg          = hero["max_dmg"].to_i
      h.armor            = hero["armor"].to_f
      h.move_speed       = hero["move_speed"]
      h.turn_rate        = hero["turn_rate"]
      h.day_sight        = hero["day_sight"]
      h.night_sight      = hero["night_sight"]
      h.attack_range     = hero["attack_range"]
      h.missile_speed    = hero["missile_speed"]
      h.front_swing      = hero["front_swing"]
      h.back_swing       = hero["back_swing"]
      h.front_cast_time  = hero["front_cast_time"]
      h.back_cast_time   = hero["back_cast_time"]
      h.base_attack_time = hero["base_attack_time"]
      h.icon             = Hero.get_icon(h.name)

      h.save!
    end
  end

    def self.hero_win_rate(match_seq_num=215706101, limit=100)
      limit.times do
        match_seq_num += 1
        match = Match.find_by(match_seq_num: match_seq_num)
        unless match.nil?
          radiant_win = match.radiant_win
          set_wins_losses(match, radiant_win)
        end
      end
    end

    def self.set_wins_losses(match, radiant_win)
      match.players.each do |player|
        valve_id = player["hero_id"]
        team     = DB.which_team(player["player_slot"])
        hero     = Hero.find_by(valve_id: valve_id)

        if ((team == "Radiant") && radiant_win) || ((team == "Dire") && !radiant_win)
          hero.wins += 1
          hero.save!
        else
          hero.losses += 1
          hero.save!
        end
      end
    end

    # 0-4 is Radiant, 128-132 is Dire
    def self.which_team(position)
      case position
      when (0..4)
        "Radiant"
      when (128..132)
        "Dire"
      end
    end

  def self.last_match
    Match.last
  end

  def self.build_matches(seq_start=215_706_100)

    # fetch according to initial release match number or last fetched
    last_fetched_seq = Match.last.match_seq_num.to_i unless Match.empty?
    last_fetched_seq ||= seq_start

    begin
      returned_matches = DotaAPI.get_match_details_by_seq(last_fetched_seq + 1)["result"]

      returned_matches["matches"].each do |match|

        detailed_match = Match.find_or_initialize_by(match_id: match["match_id"].to_s)

        if detailed_match.new_record?

          detailed_match["radiant_win"]             = match["radiant_win"]
          detailed_match["duration"]                = match["duration"]
          detailed_match["start_time"]              = match["start_time"]
          detailed_match["match_id"]                = match["match_id"]
          detailed_match["match_seq_num"]           = match["match_seq_num"]
          detailed_match["tower_status_radiant"]    = match["tower_status_radiant"]
          detailed_match["tower_status_dire"]       = match["tower_status_dire"]
          detailed_match["barracks_status_radiant"] = match["barracks_status_radiant"]
          detailed_match["barracks_status_dire"]    = match["barracks_status_dire"]
          detailed_match["cluster"]                 = match["cluster"]
          detailed_match["first_blood_time"]        = match["first_blood_time"]
          detailed_match["lobby_type"]              = match["lobby_type"]
          detailed_match["human_players"]           = match["human_players"]
          detailed_match["leagueid"]                = match["leagueid"]
          detailed_match["positive_votes"]          = match["positive_votes"]
          detailed_match["negative_votes"]          = match["negative_votes"]
          detailed_match["game_mode"]               = match["game_mode"]

          detailed_match["players"]                 = match["players"]

          # FIXME: untested, find a tournament return to make sure shape is correct
          detailed_match["picks_bans"]              = match["picks_bans"]

          puts "Saved Match ##{detailed_match["match_id"]}" if detailed_match.save!
        end
      end
      puts 'DONE.'

    rescue NoMethodError => e
      puts "Error fetching matches, is the API down?"
    end
  end
end