-- Database initial setup and seed data
-- Runs automatically when using Docker Compose

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- seed: mood definitions (8 predefined moods)
INSERT INTO mood_definitions (id, name, display_order, eyes_asset_path, mouth_asset_path, nose_asset_path, color)
VALUES
    (uuid_generate_v4(), 'happy',     1, 'assets/moods/eyes_happy.png',     'assets/moods/mouth_smile.png',   NULL, '#FFD700'),
    (uuid_generate_v4(), 'sad',       2, 'assets/moods/eyes_sad.png',       'assets/moods/mouth_frown.png',   NULL, '#4169E1'),
    (uuid_generate_v4(), 'anxious',   3, 'assets/moods/eyes_anxious.png',   'assets/moods/mouth_anxious.png', NULL, '#FF6347'),
    (uuid_generate_v4(), 'calm',      4, 'assets/moods/eyes_calm.png',      'assets/moods/mouth_calm.png',    NULL, '#90EE90'),
    (uuid_generate_v4(), 'stressed',  5, 'assets/moods/eyes_stressed.png',  'assets/moods/mouth_tense.png',   NULL, '#FF4500'),
    (uuid_generate_v4(), 'energetic', 6, 'assets/moods/eyes_energetic.png', 'assets/moods/mouth_grin.png',    NULL, '#FFA500'),
    (uuid_generate_v4(), 'tired',     7, 'assets/moods/eyes_tired.png',     'assets/moods/mouth_neutral.png', NULL, '#778899'),
    (uuid_generate_v4(), 'neutral',   8, 'assets/moods/eyes_neutral.png',   'assets/moods/mouth_neutral.png', NULL, '#B0C4DE')
ON CONFLICT (name) DO NOTHING;

-- seed: default achievements
INSERT INTO achievements (id, name, description, category, icon, xp_reward, coin_reward, condition_type, condition_value, condition_field, rarity)
VALUES
    -- study achievements
    (uuid_generate_v4(), 'First Steps',        'Complete your first study session',           'study',  'school',        25,  5,  'count',     1,   'study_sessions.count',  'common'),
    (uuid_generate_v4(), 'Bookworm',           'Complete 10 study sessions',                  'study',  'menu_book',     100, 20, 'count',     10,  'study_sessions.count',  'common'),
    (uuid_generate_v4(), 'Study Marathon',      'Study for 5 hours in a single session',      'study',  'timer',         200, 50, 'score',     300, 'study_sessions.duration', 'rare'),
    (uuid_generate_v4(), 'Perfect Score',       'Score 100% on a quiz',                       'study',  'star',          150, 30, 'score',     100, 'quizzes.percentage',    'rare'),
    (uuid_generate_v4(), 'Flash Master',        'Review 100 flashcards',                      'study',  'flash_on',      200, 40, 'count',     100, 'flashcards.reviews',    'rare'),

    -- health achievements
    (uuid_generate_v4(), 'Sleep Champion',      'Log 7 consecutive days of 7+ hours sleep',   'health', 'bedtime',       150, 30, 'streak',    7,   'sleep_logs.streak',     'rare'),
    (uuid_generate_v4(), 'Mood Tracker',        'Log your mood for 7 days straight',          'health', 'mood',          100, 20, 'streak',    7,   'mood_entries.streak',   'common'),
    (uuid_generate_v4(), 'Med Adherent',        'Take all medications on time for 7 days',    'health', 'medication',    150, 30, 'streak',    7,   'medications.adherence', 'rare'),

    -- daily achievements
    (uuid_generate_v4(), 'Habit Former',        'Complete a habit for 21 consecutive days',   'daily',  'repeat',        300, 75, 'streak',    21,  'habits.streak',         'epic'),
    (uuid_generate_v4(), 'Consistent Student',  'Log in for 30 consecutive days',             'daily',  'calendar_month',500, 100,'streak',    30,  'user.login_streak',     'legendary')
ON CONFLICT (name) DO NOTHING;
