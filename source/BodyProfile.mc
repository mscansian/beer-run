import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;

// The user's body as set on the watch: what the sober time and the beer debt
// are worked out from.
class BodyProfile {
    private var _weightKg as Float;
    private var _heightCm as Number;
    private var _age as Number;
    private var _isFemale as Boolean;

    // The profile from the watch settings, or null when weight, height, birth
    // year or gender is not set.
    static function fromWatch() as BodyProfile? {
        var profile = UserProfile.getProfile();
        var weight = profile.weight;
        var height = profile.height;
        var birthYear = profile.birthYear;
        var gender = profile.gender;
        if (weight == null || height == null || birthYear == null
            || (gender != UserProfile.GENDER_FEMALE && gender != UserProfile.GENDER_MALE)) {
            return null;
        }
        var age = Gregorian.info(Time.now(), Time.FORMAT_SHORT).year - birthYear;
        return new BodyProfile(weight / 1000.0, height, age, gender == UserProfile.GENDER_FEMALE);
    }

    function initialize(weightKg as Float, heightCm as Number, age as Number, isFemale as Boolean) {
        _weightKg = weightKg;
        _heightCm = heightCm;
        _age = age;
        _isFemale = isFemale;
    }

    function weightKg() as Float {
        return _weightKg;
    }

    // Total body water in litres, from the Watson formula. Alcohol spreads
    // through the body's water, so this sets how much one beer raises it.
    function bodyWaterLitres() as Float {
        if (_isFemale) {
            return -2.097 + 0.1069 * _heightCm + 0.2466 * _weightKg;
        }
        return 2.447 - 0.09516 * _age + 0.1074 * _heightCm + 0.3362 * _weightKg;
    }
}
