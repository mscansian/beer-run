import Toybox.Lang;

// How far you would have to run to burn off a session's beer. Running costs
// about 1 kcal per kg of body weight per km.
module BeerDebt {
    const ALCOHOL_KCAL_PER_GRAM = 7;
    // Beer has about 3.5 g of carbs per 100 ml, at 4 kcal per gram.
    const CARB_KCAL_PER_ML = 0.14;

    function km(body as BodyProfile, beers as Array<Beer>) as Float {
        return beerKcal(beers) / body.weightKg();
    }

    function beerKcal(beers as Array<Beer>) as Float {
        var kcal = 0.0;
        for (var i = 0; i < beers.size(); i++) {
            var ml = beers[i][1];
            var alcoholGrams = ml * beers[i][2] / 1000.0 * BloodAlcohol.ETHANOL_GRAMS_PER_ML;
            kcal += alcoholGrams * ALCOHOL_KCAL_PER_GRAM + ml * CARB_KCAL_PER_ML;
        }
        return kcal;
    }
}
