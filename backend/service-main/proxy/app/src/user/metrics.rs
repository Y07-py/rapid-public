pub fn compute_introduction_score(
    introduction: &str,
    ideai_size: usize,
    sentiment_score: f64,
    k: f64,
    m: f64,
) -> f64 {
    let intro_size = introduction.to_string().len() as f64;
    let f = 1.0 / (1.0 + (-k * (intro_size - ideai_size as f64)).exp());
    let g = (sentiment_score + 1.0) / 2.0;

    m * f + (1.0 - m) * g
}
