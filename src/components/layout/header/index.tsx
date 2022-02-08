import css from './header.module.css';

const Header = (): JSX.Element => {
    return(
        <div className={css.headerContainer}>
            <span className={css.logoText}>Defi Syndicate</span>
            <a href="/"><span className={css.navItem}>Home</span></a>
            <a href="/tokenomics"><span className={css.navItem}>Tokenomics</span></a>
        </div>
    );
}

export default Header;