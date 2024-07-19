pub mod Utils {
    fn pow(x: u256, n: u8) -> u256 {
        if n == 0 {
            return 1;
        }
        let half = pow(x, n / 2);
        if n % 2 == 0 {
            return half * half;
        } else {
            return half * half * x;
        }
    }
}