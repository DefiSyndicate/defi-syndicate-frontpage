import css from './footer.module.css';
import SocialLink from '../../social-link';


const Footer = (): JSX.Element => {
    return(
        <div className={`${css.footerContainer} ${css.anchorTag}`} id="socials">
            <SocialLink title="discord"></SocialLink>
            <SocialLink title="twitter"></SocialLink>
            <SocialLink title="telegram"></SocialLink>
            <SocialLink title="medium"></SocialLink>
        </div>
    );
}

export default Footer;